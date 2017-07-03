#requires -Modules PoshSecret



#stash the API key if it isn't already present, along with some other properties
if ($null -eq (Get-PoshSecret | where Name -eq Rackspace)) {
    Add-PoshSecret -Name Rackspace -Username Umberto.Ser -Password hunter2 -Property @{Account='1010101010'; Region='LON'}
}

#retrieve the API key
$ApiSecret = Get-PoshSecret | where Name -eq Rackspace | Get-PoshSecret -AsPlaintext

#Get auth token using API key
$Body = '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username":"' + $ApiSecret.Username + '","apiKey":"' + $ApiSecret.Password + '"}}}'
$Token = Invoke-RestMethod https://identity.api.rackspacecloud.com/v2.0/tokens -Method Post -Headers @{'Content-type' = 'application/json'} -Body $Body


#Use the API key as required by PoshStack
#This file needs to be cleared later
$openstackAccounts = Join-Path $env:TEMP 'CloudAccounts.csv'
New-Object psobject -Property @{
    Type = "Rackspace";
    AccountName = $ApiSecret.Username;
    CloudUsername = $ApiSecret.Username
    CloudAPIKey = $ApiSecret.Password;
    IdentityEndpointUri = $null;
    CloudDDI = $ApiSecret.Account
    Region = $ApiSecret.Region
} | Export-Csv $openstackAccounts -NoTypeInformation


try {
    Import-Module PoshStack -Force -ErrorAction Stop
} catch {
    (new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | Invoke-Expression
    Install-Module PoshStack
    Import-Module PoshStack
}




$PSDefaultParameterValues += @{'New-OpenStackComputeServer:Account' = $ApiSecret.Account}
Show-Command New-OpenStackComputeServer



$TokenObj = $Token | ConvertFrom-Json
$Url = $Token.access.serviceCatalog.endpoints | where {$_.publicUrl -match 'servers'} | select -ExpandProperty publicUrl



$Flavors = (
    Invoke-RestMethod "$Url/flavors/detail" -Method Get -Headers @{
        'X-Auth-Token' = $Token.access.token.id;
        'Content-type' = 'application/json';
        'Accept' = 'application/json';
    }
).flavors

$FlavorGen12 = $Flavors | where {$_.name -eq '2 GB General Purpose v1'}



$Images = (
    Invoke-RestMethod "$Url/images/detail" -Method Get -Headers @{
        'X-Auth-Token' = $Token.access.token.id;
        'Content-type' = 'application/json';
        'Accept' = 'application/json';
    }
).images


$BaseImages = $Images | where {$_.metadata.image_type -eq 'base'}
$WindowsBaseImages = $BaseImages | where {$_.metadata.'org.openstack__1__os_distro' -eq 'com.microsoft.server'}
$Image2012R2 = $WindowsBaseImages | where {$_.metadata.'org.openstack__1__os_version' -eq '2012.2' -and $_.name -notmatch 'OnMetal'}



$JenkinsServerName = 'FSJ1'
$Servers = (
    Invoke-RestMethod "$Url/servers/detail" -Method Get -Headers @{
        'X-Auth-Token' = $Token.access.token.id;
        'Content-type' = 'application/json';
        'Accept' = 'application/json';
    }
).servers

$JenkinsServer = $Servers | where {$_.name -eq $JenkinsServerName}



$Networks = (
    Invoke-RestMethod "$Url/os-networksv2" -Method Get -Headers @{
        'X-Auth-Token' = $Token.access.token.id;
        'Content-type' = 'application/json';
        'Accept' = 'application/json';
    }
).networks

$PublicNetworkId = '00000000-0000-0000-0000-000000000000'
$PrivateNetworkId = '11111111-1111-1111-1111-111111111111'


#$S = New-OpenStackComputeServer -ImageId $Image2012R2.id -FlavorId $FlavorGen12.id -ServerName 'FS-DC'
$ServerName = 'FS-DC'


$ProvisioningJson = 
@"
{
    "server": {
        "name": "$ServerName",
        "imageRef": "$($Image2012R2.id)",
        "flavorRef": "$($FlavorGen12.id)",
        "metadata": {
            "Owner": "$env:USERNAME"
        },
        "networks": [
            {
                "uuid": "00000000-0000-0000-0000-000000000000"
            },
            {
                "uuid": "11111111-1111-1111-1111-111111111111"
            }
        ]
    }
}
"@

$NewServerInit = (
    Invoke-RestMethod "$Url/servers" -Method Post -Headers @{
        'X-Auth-Token' = $Token.access.token.id;
        'Content-type' = 'application/json';
        'Accept' = 'application/json';
    } -Body $ProvisioningJson
).server


$NewServer = (
    Invoke-RestMethod "$Url/servers/detail" -Method Get -Headers @{
        'X-Auth-Token' = $Token.access.token.id;
        'Content-type' = 'application/json';
        'Accept' = 'application/json';
    }
).servers | where {$_.id -eq $NewServerInit.id}



Add-PoshSecret -Name $ServerName -Username 'Administrator' -Password $NewServerInit.adminPass -Property @{IP=$NewServer.accessIPv4}


<#
#Scrub credential info
$OverwriteLength = (Get-Item $openstackAccounts).Length
([string][char][byte]0xFF * $OverwriteLength) > $openstackAccounts
([string][char][byte]0x00 * $OverwriteLength) > $openstackAccounts
Remove-Item $openstackAccounts
#>

