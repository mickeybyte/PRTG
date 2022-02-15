###################################################################################################
### PRTG-HorizonTrueSSO.ps1
###
###     Shows the status of TrueSSO configured in your Horizon environment
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
    
    $TrueSSO =  Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/v1/true-sso" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    
    foreach ($TrueSSOConn in $TrueSSO) {
        
        # TrueSSO Connector status
        $name = $TrueSSOConn.name
        if ($TrueSSOConn.enabled) { # Enabled
            $status = 99
            switch ( $TrueSSOConn.status) {
                "OK" { $status = 0 }
                "WARN" { $status = 1 }
                "ERROR" { $status = 2 }
                "UNKNOWN" { $status = 99 }
            }    
        } else { $status = 10 } # Disabled
        $csr.addChannel("$name - status", $status, @{ValueLookup="prtg.standardlookups.horizon.truessostatus";HideChart=$true})

        # Primary Enrollment server status
        $status = 99
        switch ( $TrueSSOConn.primary_enrollment_server.status) {
            "OK" { $status = 0 }
            "ERROR" { $status = 2 }
        }    
        $csr.addChannel("$($TrueSSOConn.primary_enrollment_server.dns_name) [Primary]", $status, @{ValueLookup="prtg.standardlookups.horizon.truessostatus";HideChart=$true})
        
        # Seconday Enrollment server status
        $status = 99
        switch ( $TrueSSOConn.secondary_enrollment_server.status) {
            "OK" { $status = 0 }
            "ERROR" { $status = 2 }
        }    
        $csr.addChannel("$($TrueSSOConn.secondary_enrollment_server.dns_name) [Seconday]", $status, @{ValueLookup="prtg.standardlookups.horizon.truessostatus";HideChart=$true})
        
        # Certificate template status
        $status = 99
        switch ( $TrueSSOConn.template_status) {
            "OK" { $status = 0 }
            "WARN" { $status = 1 }
            "ERROR" { $status = 2 }
            "UNKNOWN" { $status = 99 }
        }
        $csr.addChannel("$($TrueSSOConn.template_name) - Certificate status", $status, @{ValueLookup="prtg.standardlookups.horizon.truessostatus";HideChart=$true})

        # Certificate servers
        foreach ($cert in $TrueSSOConn.certificate_server_details) {
            $status = 99
            switch ( $cert.status) {
                "OK" { $status = 0 }
                "WARN" { $status = 1 }
                "ERROR" { $status = 2 }
                "UNKNOWN" { $status = 99 }
            }    
            $csr.addChannel("$($cert.name) - CA status", $status, @{ValueLookup="prtg.standardlookups.horizon.truessostatus";HideChart=$true})
        }
        
    }
    # write PRTG JSON output
    write-host $csr.result()
} catch {
    $msg = "Errors occured while retrieving data from $HVUrl. Please check if all parameters are correct." 
    $csr.Error("$msg | $_")
    write-host $csr.result()
}