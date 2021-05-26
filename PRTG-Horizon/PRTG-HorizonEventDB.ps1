###################################################################################################
### PRTG-HorizonEventDB.ps1
###
###     Shows the status of the events database in your Horizon environment
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
    
    
    $eventDB = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/event-database" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)

    # Event database connection status
    switch ($eventDB.status) {
        "CONNECTED" { $status = 0 }
        "CONNECTING" { $status = 1 }
        "RECONNECTING" { $status = 2 }
        "DISCONNECTED" { $status = 3 }
        "ERROR" { $status = 4 }
        "NOT_CONFIGURED" { $status = 99 }
    }
    $csr.addChannel("Event Database status [$($eventDB.details.server_name)]", $status, @{ValueLookup="prtg.standardlookups.horizon.eventdbstatus";HideChart=$true;Primary=$true})
    
    # # events recorded
    $csr.addChannel("Total events recorded [$($eventDB.details.database_name)]", $eventDB.event_count, @{Unit="Count"})
    
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