#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Updates DNS block lists for Pi-Hole or Unbound

.DESCRIPTION
    Aggregates content from multiple curated host block lists and 
    converts into a format for use with Pi-Hole, or Unbound.

.PARAMETER OutputStyle
    Type: String
    Default: pihole
    Choose between 'pihole' and 'unbound' to format
    output to match your needs.

.PARAMETER OutputFile
    Type: Path.       
    Default: .\blocklist.txt
    The file that the blocklist is written to.

.INPUTS
    None.

.EXAMPLE
    PS> .\build-blocklist.ps1

.EXAMPLE
    PS> .\build-blocklist.ps1 -OutputStyle pihole -OutputFile /mnt/blocklist.txt

.NOTES
    Filename:   Build-Blocklist.ps1
    Author:     Tim Kennedy
    Created:    2021-04-30
    Version:    1.0
    License:    The Unlicense https://unlicense.org

.NOTES
    Changelog:
	20210501-01  fixed whitespace tabs->spaces, updated outputstring for pihole
	
	20210430-01  initial version

.LINK
    Origin List: https://v.firebog.net/hosts
#>

#Requires -Version 6
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('pihole','unbound')]
    [String]$OutputStyle='pihole',

    [Parameter(Mandatory=$false)]
    [String]$OutputFile='.\blocklist.txt'
)

Begin {
    # this is just for pretty output
    $term_width = $Host.UI.RawUI.WindowSize.Width - 8
    
    # the csv.txt master list includes urls, categories, and more than 1 level of blocking
    $source_url='https://v.firebog.net/hosts/csv.txt'
    
    # Use "ticked" lists, which require minimal manual whitelisting of false positives
    # uncomment for minimal whitelisting, low false-positives: 
    $blocklevel='tick'
    # uncomment for manual whitelisting, maybe more false positives: 
    # blocklevel="tick|std"
    # uncomment for maximum blockage, you'll need to be hands on: 
    # blocklevel="tick|std|cross"
    
    # Format the output
    if ($OutputStyle -eq 'pihole') {
        $output_string = '127.0.0.1	{0}'
    } elseif ($OutputStyle -eq 'unbound') {
        $output_string =  'local-zone: "{0}" redirect' + "`n" 
        $output_string += 'local-data: "{0}. IN A 0.0.0.0"' + "`n"
        $output_string += 'local-data: "{0}. IN AAAA ::"' 
    }
    
    function Get-UriContents {
        Param([String]$Uri)
        try {
            $res = irm -Uri $Uri -ea 0
            write-host -f green ("{0,-8}" -f "[ ok ]")
        } catch {
            if ($_.Exception.InnerException) {
                $errtxt = $_.Exception.InnerException
            } else {
                $errtxt = $_.Exception.Message
            }
            write-host -f red ("{0,-8}" -f "[ err ]")
            write-host -f yellow $errtxt
        }
        if ($res) {
            return $res
        } else {
            return "# no data returned, this line will be removed as a comment"
        }
    }
}

Process {
    # Body
    #----------------------------------------------------------------------------------------
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    
    "=" * ($term_width + 8)
    # Get the list of URLS...
    write-host -NoNewLine ("{0,-${term_width}}" -f "Grabbing master list from $source_url")
    $sources = Get-UriContents -Uri $source_url | ConvertFrom-Csv -Header "category","type","origin","desc","url"
    $time1 = $timer.Elapsed.TotalSeconds
    
    $blockhosts = New-Object System.Collections.Generic.HashSet[String]
    write-host "Grabbing individual lists:"
    foreach ($src in $sources) {
        if ($src.type -match "$blocklevel") {
            write-host -NoNewLine ("{0,-${term_width}}" -f " * $($src.desc)")
            $hosts = Get-UriContents -Uri $src.url
            $hosts = $hosts.split([Environment]::NewLine)
            $hosts = $hosts -notmatch '^\s*$' -notmatch '^::' -notmatch '^\s*#' -replace '#.*$','' -replace '^0\.0\.0\.0','' -replace '^127\.0\.0\.1','' -replace '^\s+','' 
            $hosts | %{ $blockhosts.Add($output_string -f $_) > $null }
        }
    }
    $time2 = $timer.Elapsed.TotalSeconds - $time1
    
    write-host -NoNewLine ("{0,-${term_width}}" -f "Updating OutputFile $OutputFile")
    try {
        if (Test-Path $OutputFile) { Move-Item -Force -Path "$OutputFile" -Destination "${OutputFile}.bak" }
        #Add-Content -Path ${OutputFile} -Value $blockhosts
		$blockhosts > $OutputFile
        write-host -f green ("{0,-8}" -f "[ ok ]")
    } catch {
        if ($_.Exception.InnerException) {
            $errtxt = $_.Exception.InnerException
        } else {
            $errtxt = $_.Exception.Message
        }
        write-host -f red ("{0,-8}" -f "[ err ]")
        write-host -f yellow $errtxt
    }
    $time3 = $timer.Elapsed.TotalSeconds - $time2 - $time1
}

End {
    "-" * ($term_width + 8)
    "Time Spend Downloading Master List: {0:n2} seconds" -f $time1
    "Time Spend Downloading Sub-Lists  : {0:n2} seconds" -f $time2
    "Time Spend Updating BlockList     : {0:n2} seconds" -f $time3
    "Processed {0} unique elements from {1} lists in {2:n2} seconds" -f $blockhosts.Count, ($sources|?{$_.type -match $blocklevel}).Count, $timer.Elapsed.TotalSeconds
    "=" * ($term_width + 8)
}
