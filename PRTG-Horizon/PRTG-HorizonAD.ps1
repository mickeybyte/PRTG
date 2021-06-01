###################################################################################################
### PRTG-HorizonAD.ps1
###
###     Shows the status of the AD Domain for the connection servers in your Horizon environment
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

    # Get AD Domain status from Horizon
    $adDomains = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/ad-domains" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    foreach ($domain in $adDomains) {
        
        foreach ($cs in $domain.connection_servers) {
            
            # AD Domain status for connection server
            switch ($cs.status) {
                "FULL_ACCESSIBLE" { $status = 0 }
                "UNCONTACTABLE" { $status = 1 }
                "CANNOT_BIND" { $status = 2 }
                "UNKOWN" { $status = 99 }
            }
            $csr.addChannel("Status $($domain.dns_name) - $($cs.name)", $status, @{ValueLookup="prtg.standardlookups.horizon.domainstatus";HideChart=$true;Primary=$true})
            
            # AD Domain trust status
            switch ($cs.trust_relationship) {
                "PRIMARY_DOMAIN" { $status = 0 }
                "FROM_BROKER" { $status = 1 }
                "TO_BROKER" { $status = 2 }
                "TWO_WAY" { $status = 3 }
                "TWO_WAY_FOREST" { $status = 4 }
                "MANUAL" { $status = 5 }
                "UNKOWN" { $status = 99 }
            }
            $csr.addChannel("Trust relation $($domain.dns_name) - $($cs.name)", $status, @{ValueLookup="prtg.standardlookups.horizon.domaintrust";HideChart=$true})
        }
    }

    # write PRTG JSON output
    write-host $csr.result()
} catch {
    $msg = "Errors occured while retrieving data from $HVUrl. Please check if all parameters are correct." 
    $csr.Error("$msg | $_")
    write-host $csr.result()
}