#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Updates DNS allow lists for Pi-Hole or Unbound

.DESCRIPTION
    Aggregates content from curated host allow lists and 
    converts into a format for use with Pi-Hole, or Unbound.

.PARAMETER OutputStyle
    Type: String
    Default: pihole
    Choose between 'pihole' and 'unbound' to format
    output to match your needs.

.PARAMETER OutputFile
    Type: Path.       
    Default: .\allowlist.txt
    The file that the allowlist is written to.

.INPUTS
    None.

.EXAMPLE
    PS> .\build-allowlist.ps1

.EXAMPLE
    PS> .\build-allowlist.ps1 -OutputStyle pihole -OutputFile /mnt/allowlist.txt

.NOTES
    Filename:   Build-Blocklist.ps1
    Author:     Tim Kennedy
    Created:    2021-04-30
    Version:    1.0
    License:    The Unlicense https://unlicense.org

.NOTES
    Changelog:
    20210503-01  fixed whitespace tabs->spaces, minor cosmetic changes

    20210430-01  initial checkin


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
    [String]$OutputFile='.\allowlist.txt'
)

Begin {
    # this is for formatted output
    $term_width = $Host.UI.RawUI.WindowSize.Width - 8
    
    # Since I don't have a curated list of allowlists available, this hash should make it 
    # pretty easy to add additional sources
    $sources = (
        @{
            url="https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt" 
            desc="AnudeepND's Collection of commonly whitelisted domains"
        }
    )
    
    # Format the output
    if ($OutputStyle -eq 'pihole') {
        # for pihole allow, we just need the hostname
        $output_string = '{0}'
    } elseif ($OutputStyle -eq 'unbound') {
        $output_string =  'local-zone: "{0}" always_transparent'
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
    
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    "=" * ($term_width + 8)

    $allowhosts = New-Object System.Collections.Generic.HashSet[String]
    write-host "Grabbing individual lists:"
    foreach ($source in $sources) {
        write-host -NoNewLine ("{0,-${term_width}}" -f " * $($source.desc)")
        $hosts = Get-UriContents -Uri $source.url
        $hosts = $hosts.split([Environment]::NewLine)
        $hosts = $hosts -notmatch '^\s*$' -notmatch '^::' -notmatch '^\s*#' -replace '#.*$','' -replace '^0\.0\.0\.0','' -replace '^127\.0\.0\.1','' -replace '^\s+',''
        $hosts | %{$allowhosts.Add("$output_string" -f $_) > $null }
    }
    $time1 = $timer.Elapsed.TotalSeconds

    write-host -NoNewLine ("{0,-${term_width}}" -f "Updating Output File $OutputFile")
    try {
        if (Test-Path $OutputFile) { Move-Item -Force -Path "$OutputFile" -Destination "${OutputFile}.bak" }
        $allowhosts > $OutputFile
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
    $time2 = $timer.Elapsed.TotalSeconds - $time1
}

End {
    "-" * ($term_width + 8)
    "Time Spent Downloading Lists : {0:n2} seconds" -f $time1
    "Time Spent Updating BlockList: {0:n2} seconds" -f $time2
    "Processed {0} unique elements from {1} lists in {2:n2} seconds" -f $allowhosts.Count, $sources.url.Count, $timer.Elapsed.TotalSeconds
    "=" * ($term_width + 8)

}

