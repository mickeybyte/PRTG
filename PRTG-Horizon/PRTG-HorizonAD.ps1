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
    [Parameter(Mandatory)][string]$HVUrl,       
    [Parameter(Mandatory)][string]$HVUser,      
    [Parameter(Mandatory)][string]$HVPass,      
    [Parameter(Mandatory)][string]$HVDomain     
)

# Import scripts containing general functions and classes
#   !Make sure the files are placed in the subfolder relative to this script or adjust the path here!
. "$PSScriptRoot\Horizon-Functions.ps1"
. "$PSScriptRoot\PRTG-CSR\PRTG-CSRClass.ps1"

# Main 
try {
    # Create prtgCSR object
    $csr = New-Object prtgCSR

    # Get API Access Token
    $accessToken = Open-HRConnection -username $HVUser -password $HVPass -domain $HVDomain -url $HVUrl
    
    # If using Horizon 7.x (7.10+) remove the /v2 from the REST API URL below! 
    $adDomains = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/v2/ad-domains" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
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

    #Log out of the API
    Close-HRConnection $accessToken $HVUrl

    # write PRTG JSON output
    write-host $csr.result()

}
catch {
    $msg = "Errors occured while retrieving data from $HVUrl. Please check if all parameters are correct." 
    $csr.Error("$msg | $_")
    write-host $csr.result()
}