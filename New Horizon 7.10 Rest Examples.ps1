### Use this as a jump off point to start consuming the new horizon 7.10 rest api ###

function Get-HRHeader(){
    param($accessToken)
    return @{
        'Authorization' = 'Bearer ' + $($accessToken.access_token)
        'Content-Type' = "application/json"
    }
}



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

function Close-HRConnection(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method post -uri "$url/rest/logout" -ContentType "application/json" -Body ($accessToken | ConvertTo-Json)
}


function Get-HRConnectionServers(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/connection-servers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HREventDatabase(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/event-database" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRADDomains(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/ad-domains" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRViewComposers(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/view-composers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRVirtualCenters(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/virtual-centers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRFarms(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/farms" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRRDSServers(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/rds-servers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRGateways(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/gateways" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRSAMLAuthenticators(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method Get -uri "$url/rest/monitor/saml-authenticators" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}


$url = ""

if($accessToken = Open-HRConnection -username (read-host -Prompt "username") -password (read-host -Prompt "password") -domain (read-host -Prompt "domain") -url $url){
    Get-HRConnectionServers -accessToken $accessToken -url $url
    Get-HRGateways -accessToken $accessToken -url $url
    Get-HRSAMLAuthenticators -accessToken $accessToken -url $url
    Get-HREventDatabase -accessToken $accessToken -url $url
    Get-HRADDomains -accessToken $accessToken -url $url
    Get-HRViewComposers -accessToken $accessToken -url $url
    Get-HRVirtualCenters -accessToken $accessToken -url $url
    Get-HRFarms -accessToken $accessToken -url $url
    Get-HRRDSServers -accessToken $accessToken -url $url
    Close-HRConnection -accessToken $accessToken -url $url
}

