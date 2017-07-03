#requires -Modules PoshSecret



#stash the API key if it isn't already present, along with some other properties
if ($null -eq (Get-PoshSecret | where Name -eq Rackspace)) {
    Add-PoshSecret -Name Rackspace -Username Umberto.Ser -Password hunter2 -Property @{Account='1010101010'; Region='LON'}
}

#retrieve the API key
$ApiSecret = Get-PoshSecret | where Name -eq Rackspace | Get-PoshSecret -AsPlaintext

#Get auth token using API key
$Body = '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username":"' + $ApiSecret.Username + '","apiKey":"' + $ApiSecret.Password + '"}}}'
#$Token = (
#    #Use IWR instead of IRM in order to get JSON back
#    Invoke-WebRequest https://identity.api.rackspacecloud.com/v2.0/tokens -Method Post -Headers @{'Content-type' = 'application/json'} -Body $Body
#).Content
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

$FlavorGen12 = $Flavors[13]


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


<#
#Scrub credential info
$OverwriteLength = (Get-Item $openstackAccounts).Length
([string][char][byte]0xFF * $OverwriteLength) > $openstackAccounts
([string][char][byte]0x00 * $OverwriteLength) > $openstackAccounts
Remove-Item $openstackAccounts
#>
