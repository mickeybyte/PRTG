##################################################################################################
### Horizon-Functions.ps1
###
###     General functions used by Horizon monitoring scripts 
###
### Parts of this script grabbed from 
###    https://www.retouw.nl/2020/05/15/horizonapi-getting-started-with-the-horizon-rest-api/
###    
##################################################################################################

    # Get API Header
    function Get-HRHeader(){
        param($accessToken)
        return @{
            'Authorization' = 'Bearer ' + $($accessToken.access_token)
            'Content-Type' = "application/json"
        }
    }

    # Open API Connection
    function Open-HRConnection(){
        param(
            [string] $username,
            [string] $password,
            [string] $domain,
            [string] $url
        )
        $Credentials = New-Object psobject -Property @{
            username = $username
            password = $password
            domain = $domain
        }
        return invoke-restmethod -Method Post -uri "$url/rest/login" -ContentType "application/json" -Body ($Credentials | ConvertTo-Json)
    }

    # Close API Connection
    function Close-HRConnection(){
        param(
            $accessToken,
            $url
        )
        return Invoke-RestMethod -Method post -uri "$url/rest/logout" -ContentType "application/json" -Body ($accessToken.refresh_token | ConvertTo-Json)
    }
    
    # Refresh access token
    function Update-HRConnection(){
        param(
            $accessToken,
            $url
        )
        return Invoke-RestMethod -Method post -uri "$url/rest/refresh" -ContentType "application/json" -Body ($accessToken.refresh_token | ConvertTo-Json)
    }

    # Retrieve token from file
    function Get-AccessToken() {
        param(
            [string]$SecureFile
        )
        if (Test-Path -path $SecureFile -PathType Leaf) {
            $encrypted_data = Get-Content $SecureFile | ConvertTo-SecureString
            $ptr_data = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($encrypted_data)
            $result_data = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr_data) | ConvertFrom-Json
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr_data)
        }
        # if file is found, data is returned, else null values are returned
        return @{access_token = $result_data.accessToken; refresh_token = $result_data.refreshToken} 
    }
     
    # Update access token
    function Update-AccessToken() {
        param(
            [PSCustomObject]$accessToken,
            [string]$SecureFile
        )

        if (Test-Path -path $SecureFile -PathType Leaf) {
            # securefile exists, retrieve current password (if stored)
            $encrypted_data = Get-Content $SecureFile | ConvertTo-SecureString
            $ptr_data = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($encrypted_data)
            $result_data = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr_data) | ConvertFrom-Json
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr_data)
        }
        [PSCustomObject]$data = @{
            password = $result_data.password
            accessToken = $accessToken.access_token
            refreshToken = $accessToken.refresh_token
        }
        # convert to JSON string, encrypt and save to file
        ConvertTo-SecureString $($data | ConvertTo-Json) -AsPlainText -Force | ConvertFrom-SecureString | Out-file $SecureFile
    }

    # Retrieve password from file
    function Get-Password() {
        param(
            [string]$SecureFile
        )
        if (Test-Path -path $SecureFile -PathType Leaf) {        
            $encrypted_data = Get-Content $SecureFile | ConvertTo-SecureString
            $ptr_data = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($encrypted_data)
            $result_data = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr_data) | ConvertFrom-Json
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr_data)
        }    
        # if file is found, return password, else return null
        return $result_data.password
    }
    
    # Store password in secure file
    function Update-Password(){
        param(
            [string]$pass,
            [string]$SecureFile
            )
        if ([string]::IsNullOrEmpty($pass)){
            # no password specified!
            return $false
        } else {
            # save password and quit
            [PSCustomObject]$data = @{}

            # Test if password is correct
            try {
                $accessToken = Open-HRConnection -username $HVUser -password $HVPass -domain $HVDomain -url $HVUrl
                $data.password = $pass
                if ($SaveToken) {
                    $data.accessToken = $accessToken.access_token
                    $data.refreshToken = $accessToken.refresh_token
                }
            } Catch {
                $err = $_.Exception.Response.StatusDescription
                return $false
            }

            # convert to JSON string, encrypt and save to file
            ConvertTo-SecureString $($data | ConvertTo-Json) -AsPlainText -Force | ConvertFrom-SecureString | Out-file $SecureFile
            return $true
        }
    }

    # Process input parameters, store password if needed and retrieve access tokens
    function process-Parameters() {
        if ($SavePassword) {
            # if -SavePassword is given, only save password and exit. No monitoring is done!
            if (Update-Password -pass $HVPass -secureFile $SecureFile) {
                # return error: pass saved, remove parameter
                $csr.Error("Password saved. Please remove -SavePassword parameter now!")
            } else {
                # return error: pass not saved, check parameters
                if ([string]::IsNullOrWhiteSpace($err)){
                $csr.Error("parameter -SavePassword given without password!")
                } else {
                    $csr.Error("Password check failed: $($err)")
                }
            }
            write-host $csr.result()
            exit
        }
        
        # if password is empty, check if it is stored
        if ([string]::IsNullOrEmpty($HVPass)) { $HVPass = Get-Password($SecureFile)}
        # if password is still empty, no password is stored of passed as parameter
        if ([string]::IsNullOrEmpty($HVPass)) { 
            $csr.Error("No password supplied or found")
            write-host $csr.result()
            exit
        }
        
        # retrieve access token from secure file
        $accessToken = Get-AccessToken($SecureFile)
        # Check authentication to REST API
        try { 
            # do REST API call to check if access token still valid
            $test = Invoke-RestMethod -Method Get -uri "$HVurl/rest/monitor/ad-domains" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
            #$csr.Text = "Auth: OK"
        } Catch {
            # unauthorized, get new access token using refresh token
            try {
                $accessToken = Update-HRConnection -url $HVUrl -accessToken $accessToken
                #$csr.Text = "Auth: Refreshed"
                # if SaveToken, store new tokens
                if ($SaveToken) { 
                    Update-AccessToken -accessToken $accessToken -secureFile $SecureFile
                    #$csr.Text += " & saved" 
                }
            } Catch {
                # refresh failed, start login to obtain new access token
                try {
                    $accessToken = Open-HRConnection -username $HVUser -password $HVPass -domain $HVDomain -url $HVUrl
                    #$csr.Text = "Auth: New token"
                    if ($SaveToken) { 
                        Update-AccessToken -accessToken $accessToken -secureFile $SecureFile 
                        #$csr.Text += " & saved"
                    }
                } catch {
                    # all re-authentication methods failed, raise error and exit
                    $csr.Error("Failed to authenticate: $($_.Exception.Response.StatusDescription)")
                    write-host $csr.result()
                    exit
                }
            }
        }

        return $accessToken
    }