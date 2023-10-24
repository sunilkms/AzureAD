#--------------------------------------------------------------------------------------------
# This script helps find the SP of the role
# This is needed when granting a role to an SP without associated App registration.
#--------------------------------------------------------------------------------------------

param($FindSPofRole="Machine.read.all") #e.g. :: Machine.read.all
$AllServicePrincipal=Get-MgServicePrincipal -All:$true
$appswithApi=$AllServicePrincipal | ? {$_.AppRoles}
$appswApi=$appswithApi | ? {$_.SignInAudience -ne "AzureADMyOrg" -and $_.SignInAudience -ne $null}
$appswApi | ? {$_.AppRoles.Value -eq $FindSPofRole}
