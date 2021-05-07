Learning powershell.  The challenge here was to download a list of urls that contain decently curated (mostly) sources for hostnames to blocklist for various reasons (malware, ads, spam, crypto-mining, etc)

# pihole-list-updater
Powershell scripts to manage Pi-Hole's block and allow lists using public curated sources

### build-allowlist.ps1
* processes community allowlist(s) and outputs formats for use with pi-hole or unbound	

### build-blocklist.ps1
* processes community blocklist(s) and outputs formats for use with pi-hole or unbound	

## To-Do:
* have the scripts directly update gravitydb rather than the older text file style of blocklist/allowlist

## Note:
* these scripts are as-is. :)
