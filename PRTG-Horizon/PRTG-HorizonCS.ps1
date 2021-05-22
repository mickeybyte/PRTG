###################################################################################################
### PRTG-HorizonCS.ps1
###
###     Shows the status of the connection servers in your Horizon environment, using a single sensor with different channels
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
    
    $ConnServers = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/v2/connection-servers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    foreach ($cs in $ConnServers) {
        $name = $cs.name
        # General Horizon status
        switch ($cs.status) {
            "OK" { $status = 0 }
            "ERROR" { $status = 1 }
            "NOT_RESPONDING" { $status = 2 }
            "UNKOWN" { $status = 3 }
        }
        $csr.addChannel("$name Status", $status, @{ValueLookup="prtg.standardlookups.horizon.status";HideChart=$true;Primary=$true})
        
        # # connections
        $csr.addChannel("$name Connections", $cs.connection_count)
        # # tunneled connections
        $csr.addChannel("$name Tunnel connections", $cs.tunnel_connection_count)
        # LDAP replication status between connection servers
        foreach ($repl in $cs.cs_replications) {
            switch ($repl.status) {
                "OK" { $replstatus = 0 }
                "ERROR" { $replstatus = 1 }
            }
            $csr.addChannel("$name Replication with $($repl.server_name)", $replstatus, @{ValueLookup="prtg.standardlookups.horizon.replstatus";HideChart=$true})
        }

        # Gateway services status
        foreach ($svc in $cs.services) {
            switch ($svc.status) {
                "UP" { $svcStatus = 0 }
                "DOWN" { $svcStatus = 1 }
                "UKNOWN" { $svcStatus = 99 }
            }
            $csr.addChannel("$name $($svc.service_name)", $svcStatus, @{ValueLookup="prtg.standardlookups.horizon.servicestatus";hideChart=$true})
        }
        
        # Certifiate status
        if ($cs.certificate.valid) { $csr.addChannel("$name valid certificate", 1, @{ValueLookup="prtg.standardlookups.yesno.stateyesok"})}
        else { $csr.addChannel("$name valid certificate", 2, @{ValueLookup="prtg.standardlookups.yesno.stateyesok"})}

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