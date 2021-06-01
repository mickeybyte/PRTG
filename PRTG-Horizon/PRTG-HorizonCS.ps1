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
    
    $ConnServers = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/connection-servers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
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
    # write PRTG JSON output
    write-host $csr.result()
} catch {
    $msg = "Errors occured while retrieving data from $HVUrl. Please check if all parameters are correct." 
    $csr.Error("$msg | $_")
    write-host $csr.result()
}