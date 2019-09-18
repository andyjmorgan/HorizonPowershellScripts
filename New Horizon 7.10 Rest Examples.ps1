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
        [string] $domain
    )

    $Credentials = New-Object psobject -Property @{
        username = $username
        password = $password
        domain = $domain
    }
    return invoke-restmethod -Method Post -uri "https://pod1hcon2.lab.local/rest/login" -ContentType "application/json" -Body ($Credentials | ConvertTo-Json)
}

function Close-HRConnection(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method post -uri "https://pod1hcon2.lab.local/rest/logout" -ContentType "application/json" -Body ($accessToken | ConvertTo-Json)
}


function Get-HRConnectionServers(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/connection-servers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HREventDatabase(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/event-database" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRADDomains(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/ad-domains" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRViewComposers(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/view-composers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRVirtualCenters(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/virtual-centers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRFarms(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/farms" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRRDSServers(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/rds-servers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRGateways(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/gateways" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

function Get-HRSAMLAuthenticators(){
    param(
        $accessToken
    )
    return Invoke-RestMethod -Method Get -uri "https://pod1hcon2.lab.local/rest/monitor/saml-authenticators" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
}

if($accessToken = Open-HRConnection -username (read-host -Prompt "username") -password (read-host -Prompt "password") -domain (read-host -Prompt "domain")){
    Get-HRConnectionServers -accessToken $accessToken
    Get-HRGateways -accessToken $accessToken
    Get-HRSAMLAuthenticators -accessToken $accessToken
    Get-HREventDatabase -accessToken $accessToken
    Get-HRADDomains -accessToken $accessToken
    Get-HRViewComposers -accessToken $accessToken
    Get-HRVirtualCenters -accessToken $accessToken
    Get-HRFarms -accessToken $accessToken
    Get-HRRDSServers -accessToken $accessToken
    Close-HRConnection -accessToken $accessToken
}

