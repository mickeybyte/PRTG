###################################################################################################
### PRTG-HorizonGW.ps1
###
###     Shows the status of the gateways in your Horizon environment, using a single sensor with different channels
###
### Parts of this script grabbed from 
###    https://www.retouw.nl/2020/05/15/horizonapi-getting-started-with-the-horizon-rest-api/
###    
###################################################################################################


# Specify default values here or use command line parameters. 
# If nothing is specified, you will be prompted for mandatory parameters
param (
    [string]$HVUrl,         # Horizon connection server URL (https://connectionserver.domain.local)
    [string]$HVUser,        # Horizon administrator user with access to root level
    [string]$HVPass="",     # Horizon password (if empty it will be retrieved form secure file)
    [string]$HVDomain,      # Horizon AD domain
    [bool]$SaveToken=$true, # API authentication token is saved to secure file to be re-used by this or other Horizon scripts
    [switch]$SavePassword=$false,   # If true, password will be saved to secure file (only to be used once to save password)
    [string]$SecureFile="$PSScriptRoot\Horizon-Functions.dat"   # secure file used to save or retrieve password and/or authentication token
)

# Import scripts containing general functions and classes
#   !Make sure the files are placed in the subfolder relative to this script or adjust the path here!
. "$PSScriptRoot\Horizon-Functions.ps1"
. "$PSScriptRoot\PRTG-CSR\PRTG-CSRClass.ps1"

# Main 
try {
    # Create prtgCSR object
    $csr = New-Object prtgCSR

    # process parameters and initialize authentication
    $accessToken = process-Parameters
    
    $gateways =  Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/gateways" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    
    foreach ($gw in $gateways) {
        
        $name = $gw.name
        # General status
        switch ($gw.status) {
            "OK" { $status = 0 }
            "PROBLEM" { $status = 1 }
            "NOT_CONTACTED" { $status = 2 }
            "UNKNOWN" { $status = 99 }
        }
        $csr.addChannel("$name", $status, @{ValueLookup="prtg.standardlookups.horizon.gwstatus";HideChart=$true;Primary=$true})
        
        # # connections
        $csr.addChannel("$name Active connections", $gw.active_connection_count)
        # # BLAST connections
        $csr.addChannel("$name BLAST connections", $gw.blast_connection_count)
        # # PCoIP connections
        $csr.addChannel("$name PCoIP connections", $gw.pcoip_connection_count)

    }
    # write PRTG JSON output
    write-host $csr.result()
} catch {
    $msg = "Errors occured while retrieving data from $HVUrl. Please check if all parameters are correct." 
    $csr.Error("$msg | $_")
    write-host $csr.result()
}