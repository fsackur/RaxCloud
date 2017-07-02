#requires -Modules PoshSecret



#stash the API key if it isn't already present
if ($null -eq (Get-PoshSecret | where Name -eq Rackspace)) {
    Add-PoshSecret -Name Rackspace -Username Umberto.Ser -Password hunter2 -Property @{Account='1010101010'; Endpoint='LON'}
}

#retrieve the API key
$ApiSecret = Get-PoshSecret | where Name -eq Rackspace | Get-PoshSecret -AsPlaintext





#Use the API key as required by PoshStack
#This file needs to be cleared later
$openstackAccounts = "C:\temp\CloudAccounts.csv"
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
    Import-Module PoshStack -Force
} catch {
    (new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | Invoke-Expression
    Install-Module PoshStack
    Import-Module PoshStack
}


#Scrub credential info
$OverwriteLength = (Get-Item $openstackAccounts).Length
([string][char][byte]0xFF * $OverwriteLength) > $openstackAccounts
([string][char][byte]0x00 * $OverwriteLength) > $openstackAccounts
Remove-Item $openstackAccounts



