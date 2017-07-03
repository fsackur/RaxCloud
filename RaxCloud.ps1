#requires -Modules PoshSecret



#stash the API key if it isn't already present, along with some other properties
if ($null -eq (Get-PoshSecret | where Name -eq Rackspace)) {
    Add-PoshSecret -Name Rackspace -Username Umberto.Ser -Password hunter2 -Property @{Account='1010101010'; Region='LON'}
}

#retrieve the API key
$ApiSecret = Get-PoshSecret | where Name -eq Rackspace | Get-PoshSecret -AsPlaintext

#Get auth token using API key
$Body = '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username":"' + $ApiSecret.Username + '","apiKey":"' + $ApiSecret.Password + '"}}}'
$Token = (
    #Use IWR instead of IRM in order to get JSON back
    Invoke-WebRequest https://identity.api.rackspacecloud.com/v2.0/tokens -Method Post -Headers @{'Content-type' = 'application/json'} -Body $Body
).Content



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


<#
#Scrub credential info
$OverwriteLength = (Get-Item $openstackAccounts).Length
([string][char][byte]0xFF * $OverwriteLength) > $openstackAccounts
([string][char][byte]0x00 * $OverwriteLength) > $openstackAccounts
Remove-Item $openstackAccounts
#>