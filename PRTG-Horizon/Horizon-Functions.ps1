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

    #Close API Connection
    function Close-HRConnection(){
        param(
            $accessToken,
            $url
        )
        return Invoke-RestMethod -Method post -uri "$url/rest/logout" -ContentType "application/json" -Body ($accessToken.refresh_token | ConvertTo-Json)
    }

