#------------------------------------------------------------------------------------
# Author: Sunil Chauhan <sunilkms@gmail.com>
# Fetch All Cloud admin Accounts
# Fetch their related permissions
# 
# Fetch all Cloud Service accounts
# Fetch their Azure AD Roles
#
# Fetch all the Roles
# fetch their member and get non-user accounts.
#
# create department vise report.
# 
#-------------------------------------------------------------------------------------
$ReportDir="D:\script\Reports\"
$CAA= $ReportDir + "AAD-Roles-Report-CSA-Account-Based-$(get-date -f "dd-MM-yyyy").csv"
$CSA=$ReportDir + "AAD-Roles-Report-CaA-Account-Based-$(get-date -f "dd-MM-yyyy").csv"
$NONU=$ReportDir + "AAD-Roles-Report-non-user-Account-Based-$(get-date -f "dd-MM-yyyy").csv"

# Preload the functions collections.
. "D:\script\MainFunctions.ps1"

$sec="D:\script\secret.txt"
$appID="APP ID"
$dirid="DIR ID"

$Global:AccessToken=FetchAccessToken -AppID $appID -DirID $dirid -secretFile $sec
ConnectMGGraph -AccessToken $AccessToken

#CAA -------------------- eg domain: "caa.lab365.in"
$CaaUsers=get-MgUser -Filter "proxyAddresses/any(p:endswith(p,'caa.lab365.in'))" -CountVariable CountVar -ConsistencyLevel eventual -All -Property id,AccountEnabled,UserPrincipalName,DisplayName

$AllUsers=$CaaUsers | select id,AccountEnabled,UserPrincipalName,DisplayName,
@{N="Department";E={if ($_.DisplayName -match "/") {"(" + $_.DisplayName.Split("(")[1]} else {"BreakGlassAC"} }},
@{N="Manager";e={(Get-MgUserManager -UserId $_.id).AdditionalProperties.mail}}
$dg=$AllUsers | group Department | sort count -Descending| Select Name,Count
$dgh=$dg | select -First 10 | ConvertTo-Html -Fragment

#$reportdata | 
ConnectAzureAD

#Fetch roles info
$TenantID=(Get-MgContext).TenantId
$AdminRoles=Get-AzureADMSPrivilegedRoleDefinition -ProviderId aadRoles -ResourceId $TenantId -ErrorAction Stop | select Id, DisplayName

function Get-UserAssignedRoles {
param($TenantId='tenantID',$user)
$AzureUser = Get-AzureADUser -ObjectId $User -ErrorAction Stop | select DisplayName, UserPrincipalName, ObjectId,OtherMails
$UserRoles = Get-AzureADMSPrivilegedRoleAssignment -ProviderId aadRoles -ResourceId $TenantId -Filter "subjectId eq '$($AzureUser.ObjectId)'"
 
                    if ($UserRoles) 
                    {
                        foreach ($Role in $UserRoles) 
                            {
                            $RoleObject = $AdminRoles | Where-Object {$Role.RoleDefinitionId -eq $_.id} 
               [PSCustomObject]@{
                                UserPrincipalName = $AzureUser.UserPrincipalName
                                AzureADRole       = $RoleObject.DisplayName
                                PIMAssignment     = $Role.AssignmentState
                                MemberType        = $Role.MemberType
                                OtherMails        = $AzureUser.OtherMails
                                }
                            }
                    }
    }
$report=@()
foreach ($user in $AllUsers)
{
Write-Host "Fetchinged assigned role for:$($user.UserPrincipalName)"
$R=Get-UserAssignedRoles -user $user.id | select AzureADRole,PIMAssignment,MemberType,@{N="OtherMails";E={$_.OtherMails}}
$role=$user | select id,AccountEnabled,UserPrincipalName,DisplayName,Department,
@{N="AzureADRole";E={$R.AzureADRole -join ";"}},
@{N="NumberofRoleAssigned";E={($R.AzureADRole | select -Unique).count}},
@{N="PIMAssignment";E={$R.PIMAssignment | select -Unique}},
@{N="MemberType";E={$R.MemberType | select -Unique}},
@{N="LinkedAccount";E={$_.Manager}}

$report+=$role
}

$report | export-csv $CAA -NoTypeInformation
$dcsah=$Report | ? {$_.AccountEnabled -match "False"} | select UserPrincipalName,AccountEnabled,Department,NumberofRoleAssigned | ConvertTo-Html -Fragment
#CSA ---------------------

#Cloud service account === eg Domain is : "csa.lab365.in"
$CSAUsers=get-MgUser -Filter "proxyAddresses/any(p:endswith(p,'csa.lab365.in'))" -CountVariable CountVar -ConsistencyLevel eventual -All -Property id,AccountEnabled,UserPrincipalName,DisplayName

$reportcsa=@()
foreach ($user in $CSAUsers)
{
Write-Host "Fetchinged assigned role for:$($user.UserPrincipalName)"
$reportcsa+=Get-UserAssignedRoles -user $user.id | select UserPrincipalName,AzureADRole,PIMAssignment,MemberType,@{N="OtherMails";E={$_.OtherMails}},
@{N="AccountEnabled";E={$user.AccountEnabled}},@{N="Department";E={$user.Department}},@{N="DisplayName";E={$user.DisplayName}}
}

$reportcsa | export-csv $CSA -NoTypeInformation

# find non user with AzureAd Roles

$RoleId = @{}
$AdminRoles | ForEach-Object {$RoleId.Add($_.DisplayName, $_.Id)}

$nonUser=@()
foreach ($role in $AdminRoles) {
$RoleName=$role.DisplayName
Write-Host "Processing role::$($RoleName)" 
$R=Get-AzureADMSPrivilegedRoleAssignment -ProviderId aadRoles -ResourceId $TenantId -Filter "RoleDefinitionId eq '$($RoleId[$RoleName])'" -ErrorAction Stop | ` 
select RoleDefinitionId, SubjectId, StartDateTime, EndDateTime, AssignmentState, MemberType

$nonUser+=$r | % {
            try{
                $sub=$_.SubjectId;
                Get-AzureADUser -ObjectId $sub -ErrorAction SilentlyContinue
                }
           catch{Get-AzureADServicePrincipal -ObjectId $sub}
           } | ? {$_.ObjectType -ne "User"} | select DisplayName,@{N="RoleAssigned";E={$RoleName}},ObjectType,AccountEnabled
}

$nonUser | export-csv $NONU -NoTypeInformation
$serviceAccountHtml = $reportcsa | group UserPrincipalName  | select Name,@{N="AccountEnabled";E={$($_.group.AccountEnabled) | select -Unique}},
@{N="AzureADRole";E={$_.group.AzureADRole -join ";" }} | ConvertTo-Html -Fragment

$nonUserHtml=$nonUser | group RoleAssigned  | select Name,Count | ConvertTo-Html -Fragment
$globaladminsHTM=($report | group AzureADrole | ? {$_.Name -match "Global Administrator"}).group | select UserPrincipalName,PIMAssignment, 
@{N="Department";e={if($_.Department -eq "("){"NONE"}else {$_.Department}}} | ConvertTo-Html -Fragment

$HTMLReport="AzureAD-Roles-Summary.htm"
$css='
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
* {
  box-sizing: border-box;
}

/* Create four equal columns that floats next to each other */
.column {
  float: left;
  width: 50%;
  padding: 10px;
  /* height: 300px;  Should be removed. Only for demonstration */
}

/* Clear floats after the columns */
.row:after {
  content: "";
  display: table;
  clear: both;
}
</style>
</head>
<body>
'
$bodyBox=@"
$css
<h2>Azure AD Roles summary Report</h2>
<div class="row">
  <div class="column" style="background-color:#33E3FF;">
    <h4>Roles Summary</h4>
    <p>
       Total caa.nokia.com Accounts with roles =$(($report | group UserPrincipalName).count)</br>
       Total csa.nokia.com Accounts with roles =$(($reportcsa | group UserPrincipalName).count)</br>
       Total AzureAD Applications with role assignment=$(($nonUser | group DisplayName).count)</br>
       Total Global Admins in Org=$(($report | group AzureADrole | ? {$_.Name -match "Global Administrator"}).Count)</br>       
       </br></br></br>      
    </p> 
  </div>

  <div class="column" style="background-color:#DAF7A6;">
    <h4>Azure AD Applications with Azure AD role Assignment</h4>
    $nonUserHtml
   </p> 
  </div>

  <div class="column" style="background-color:#FFF933;">
    <h4>Service Accounts With Active Role Assignement</h4>
    $serviceAccountHtml  
  </div>
  <div class="column" style="background-color:#FF9033;">
   <h4>Global Admins in Organization</h4>
   $globaladminsHTM
</div>
</div>
  <div class="column" style="background-color:#ddd;">
  <h4>Top 10 departments with the admin accounts</h4>
    $dgh
  </div>
  <div class="column" style="background-color:#ddd;">
  <H4>Disabled CAA accounts</h4>
   $dcsah
  </div>
</div>
</body>
</html>
"@
$bodyBox > $HTMLReport
$Body=(gc $HTMLReport | Out-String)
$attach=$CAA,$CSA,$NONU,$HTMLReport
$from="Sunil.chauhan@xyz.com"
$to="Sunil.chauhan@xyz.com"
$subject="Azure AD Role Assignment analyses"
Send-MailMessage -From $from -To $to -Subject $subject -SmtpServer "My.smtp.server" -Body $body -BodyAsHtml -Attachments $attach
#Send-MailMessage
