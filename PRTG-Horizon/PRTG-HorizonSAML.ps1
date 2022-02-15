###################################################################################################
### PRTG-HorizonSAML.ps1
###
###     Shows the status of the SAML authenticators configured in your Horizon environment
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
    
    $SAMLAuths =  Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/saml-authenticators" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    
    foreach ($sa in $SAMLAuths) {
        
        $name = $sa.details.label
        $csr.addChannel("$name - # enabled servers", $sa.connection_servers.Count, @{HideChart=$true})
        foreach($cs in $sa.connection_servers) {
            # SAML status
            switch ($cs.status) {
                "OK" { $status = 0 }
                "WARN" { $status = 1 }
                "ERROR" { $status = 2 }
                "UNKNOWN" { $status = 99 }
            }
            $csr.addChannel("$name - $($cs.name)", $status, @{ValueLookup="prtg.standardlookups.horizon.samlstatus";HideChart=$true})
        }
    }
    # write PRTG JSON output
    write-host $csr.result()
} catch {
    $msg = "Errors occured while retrieving data from $HVUrl. Please check if all parameters are correct." 
    $csr.Error("$msg | $_")
    write-host $csr.result()
}