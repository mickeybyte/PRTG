###################################################################################################
### PRTG-HorizonRDSFarm.ps1
###
###     Shows the status of the RDS Farms and hosts in your Horizon environment
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
    $RDSFarms = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/farms" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    $RDSServers = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/rds-servers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    foreach ($farm in $RDSFarms) {
        
        $farmID = $farm.id 

        # RDS status
        switch ($farm.status) {
            "OK" { $status = 0 }
            "WARNING" { $status = 1 }
            "ERROR" { $status = 2 }
            "DISABLED" { $status = 3 }
        }
        $csr.addChannel("$($farm.name)", $status, @{ValueLookup="prtg.standardlookups.horizon.rdsstatus";HideChart=$true})
        # Number of RDS Servers in farm
        $csr.addChannel("$($farm.name) servers", $farm.rds_server_count)
        # Number of applications in farm
        $csr.addChannel("$($farm.name) applications", $farm.application_count)
        
        # Get details of all RDS servers for this farm
        foreach ($rds in $RDSServers) {
            # limit to RDS servers for this farm
            if ($rds.farm_id -eq $farmID) {
                # RDS server status
                switch ($rds.status) {
                    "OK" { $status = 0 }
                    "WARNING" { $status = 1 }
                    "ERROR" { $status = 2 }
                    "DISABLED" { $status = 3 }
                }
                $csr.addChannel("$($farm.name)[$($rds.name)]", $status, @{ValueLookup="prtg.standardlookups.horizon.rdsstatus";HideChart=$true})
                # RDS server agent status
                switch ($rds.details.state) {
                    "AVAILABLE" { $status = 0 }
                    "DISABLED" { $status = 1 }
                    "CONNECTED" { $status = 2 }
                    "WAIT_FOR_AGENT" { $status = 3 }
                    "DISABLE_IN_PROGRESS" { $status = 4 }
                    "PROVISIONING" { $status = 5 }
                    "CUSTOMIZING" { $status = 6 }
                    "DELETING" { $status = 7 }
                    "MAINTENANCE" { $status = 8 }
                    "PROVISIONED" { $status = 9 }
                    "DISCONNECTED" { $status = 10 }
                    "AGENT_ERR_STARTUP_IN_PROGRESS" { $status = 11 }
                    "AGENT_DRAIN_MODE" { $status = 12 }
                    "AGENT_DRAIN_UNTIL_RESTART" { $status = 13 }
                    "IN_PROGRESS" { $status = 14 }
                    "VALIDATING" { $status = 15 }
                    "AGENT_UNREACHABLE" { $status = 16 }
                    "AGENT_CONFIG_ERROR" { $status = 17 }
                    "PROVISIONING_ERROR" { $status = 18 }
                    "ERROR" { $status = 19 }
                    "AGENT_ERR_DISABLED" { $status = 20 }
                    "AGENT_ERR_INVALID_IP" { $status = 21 }
                    "AGENT_ERR_NEED_REBOOT" { $status = 22 }
                    "AGENT_ERR_PROTOCOL_FAILURE" { $status = 23 }
                    "AGENT_ERR_DOMAIN_FAILURE" { $status = 24 }
                    "ALREADY_USED" { $status = 25 }
                    "UNKNOWN" { $status = 99 }
                }
                $csr.addChannel("$($farm.name)[$($rds.name)] agent", $status, @{ValueLookup="prtg.standardlookups.horizon.rdsagentstatus";HideChart=$true})
                # RDS Server session count
                $csr.addChannel("$($farm.name)[$($rds.name)] sessions", $rds.session_count)
                # Load status retrieved from Horizon (based on load balancing settings)
                $csr.addChannel("$($farm.name)[$($rds.name)] load", $rds.load_index, @{Unit="Percent"})
                switch ($rds.load_preference) {
                    "LIGHT" { $status = 0 }
                    "NORMAL" { $status = 1 }
                    "HEAVY" { $status = 2 }
                    "BLOCK" { $status = 3 }
                    "UNKNOWN" { $status = 99 }
                }
                $csr.addChannel("$($farm.name)[$($rds.name)] load Status", $status, @{ValueLookup="prtg.standardlookups.horizon.rdsloadstatus";HideChart=$true})
            }
        }
    }

    # write PRTG JSON output
    write-host $csr.result()
} catch {
    $msg = "Errors occured while retrieving data from $HVUrl. Please check if all parameters are correct." 
    $csr.Error("$msg | $_")
    write-host $csr.result()
}