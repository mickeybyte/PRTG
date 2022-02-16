###################################################################################################
### PRTG-HorizonvCenter.ps1
###
###     Shows the status of vCenters in your Horizon environment
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
    
    $vCenters = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/v2/virtual-centers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    foreach ($vc in $vCenters) {
        $name = $vc.name -replace "https://","" -replace ":443/sdk" # default name = https://<vcenter>:443/sdk", so remove unwanted parts
        
        # Check connection from Connection servers to vCenter
        foreach ($cs in $vc.connection_servers) {
            $status = 99
            switch ($cs.status) {
                "OK" { $status = 0 }
                "DOWN" { $status = 2 }
                "RECONNECTING" { $status = 1 }
                "UNKNOWN" { $status = 99 }
                "INVALID_CREDENTIALS" { $status = 4 }
                "CANNOT_LOGIN" { $status = 3 }
                "NOT_YET_CONNECTED" { $status = 90}
            }
            $csr.addChannel("$name - $($cs.name)", $status, @{ValueLookup="prtg.standardlookups.horizon.vcenterstatus";HideChart=$true})
        }

        # Check Datastore status and capacity
        foreach ($ds in $vc.datastores) {
            switch ($ds.status) {
                "ACCESSIBLE" { $status = 0 }
                "INACCESSIBLE" { $status = 1 }
            }
            $csr.addChannel("$($ds.details.name) [$($ds.type)] - status", $status, @{ValueLookup="prtg.standardlookups.horizon.status";HideChart=$true})
            $csr.addChannel("$($ds.details.name) [$($ds.type)] - Free space", [int]($ds.free_space_mb / $ds.capacity_mb * 100), @{Float=$true;Unit="Percent"})
        }

        # Check Hosts
        foreach ($vcHost in $vc.hosts) {
            $status = 99
            switch ($vcHost.status) {
                "CONNECTED" { $status = 0 }
                "DISCONNECTED" { $status = 1 }
                "NOT_RESPONDING" { $status = 2 }
            }
            $csr.addChannel("$($vcHost.details.name) [$($vcHost.details.cluster_name)]", $status, @{ValueLookup="prtg.standardlookups.horizon.hoststatus";HideChart=$true})

        }
    }
    # write PRTG JSON output
    write-host $csr.result()
} catch {
    $msg = "Errors occured while retrieving data from $HVUrl. Please check if all parameters are correct." 
    $csr.Error("$msg | $_")
    write-host $csr.result()
}