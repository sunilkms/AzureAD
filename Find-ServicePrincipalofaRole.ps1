#--------------------------------------------------------------------------------------------
# This script helps find the SP of the role
# This is needed when granting a role to an SP without associated App registration.
#--------------------------------------------------------------------------------------------

param($FindSPofRole="Machine.read.all") #e.g. :: Machine.read.all
$AllServicePrincipal=Get-MgServicePrincipal -All:$true
$appswithApi=$AllServicePrincipal | ? {$_.AppRoles}
$appswApi=$appswithApi | ? {$_.SignInAudience -ne "AzureADMyOrg" -and $_.SignInAudience -ne $null}
$appswApi | ? {$_.AppRoles.Value -eq $FindSPofRole}

#add role - 
<#
param(
# Name of the manage identity (same as the Logic App name)
$DisplayNameOfMSI="my app",
# Check the Microsoft Graph documentation for the permission you need for the operation
$PermissionName="ThreatHunting.Read.All"# eg:GroupMember.Read.All
)
#Microsoft Graph App ID (DON'T CHANGE)
$GraphAppId = "00000003-0000-0000-c000-000000000000"
#Microsoft Defender API ID.
#$GraphAppId= "fc780465-2017-40d4-a0c5-307022471b92" #"416e2f8f-3a3c-4a31-b089-4f3490927e17"
$MSI=(Get-AzureADServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'")
$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"
$AppRole = $GraphServicePrincipal.AppRoles | ? {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId `
-ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
#>
