#requires -Modules PoshSecret

#stash the API key if it isn't already present
if ($null -eq (Get-PoshSecret | where Name -eq Rackspace)) {
    Add-PoshSecret -Name Rackspace -Username Umberto.Ser -Password hunter2 -Property @{Account='1010101010'}
}

#retrieve the API key
$ApiKey = Get-PoshSecret | where Name -eq Rackspace | Get-PoshSecret -AsPlaintext | select -ExpandProperty Password

