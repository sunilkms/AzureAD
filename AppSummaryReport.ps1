#AZURE AD APP SUMMARY REPORT
# AUTHOR: SUNIL CHAUHAN

#region - UPDATE ME Variables-------------------------

#App Details
$appID="<App ID>"
$dirid="Dir ID"
$SecretFile="D:\myscripts\secret.txt"

#Dir Paths
$reportPAth="D:\Myscripts\Reports"
$reportLogPath="D:\MyScripts\Logs"
$MainFunctionsDir="D:\Myscripts"
$MainFunctions="$MainFunctionsDir\MainFunctions.ps1"

#rec Info
$HTMLReport="$reportPAth\AAD_App_SummaryReport.htm"
$from="sunil@lab365.in"
$to="sunil@lab365.in"
$smtp="smtp.lab365.in"
$guestAccountNameFilture="EXAMPLE" # Change me as per the guest display name.
#endregion

write-host "Starting transcript..."
Start-Transcript -Path $("$reportLogPath\MG_AppRegSummary_script-$(get-date -f "dd-MM-yyyy").log")
$mgAppsRegInventory="$reportPAth\MgAppsRegInventory-$(get-date -f "dd-MM-yyyy").csv"
$mgEntAppsRegInventory="$reportPAth\MgEntAppsInventory-$(get-date -f "dd-MM-yyyy").csv"

#region--Support Functions
#graph api details

Write-Host "Connecting to Microsoft Graph.."
Import-Module $MainFunctions 

$AccessToken=FetchAccessToken -AppID $appID -DirID $dirid -secretFile $SecretFile
ConnectMGGraph -AccessToken $AccessToken
#GetJWTDetails -token $AccessToken
#----------------------------------------------------------------------------------------------
# APPLICATION REGISTRATION BLOCK
#----------------------------------------------------------------------------------------------

$Applications=Get-MgApplication -All

$c=0;$rawdata=@()
Write-Host "Total Apps::$($Applications.count)"
foreach ($app in $Applications) {
$c++
$TA=CheckTokenAgeandReconnect
$appASOwner="NO"
$appASOwnerName=@()
$upn=@()
try {
        Write-Host "Fetching owners Stats:[TA=$TA]:[$c]:$($app.DisplayName)"
        $owners=(Get-MGApplicationOwner -ApplicationId $app.Id -ea SilentlyContinue)
             if ($owners){
                    if (($owners.AdditionalProperties.servicePrincipalType) -and ($owners.AdditionalProperties.userPrincipalName)){
                     $upn=$($owners.AdditionalProperties.userPrincipalName) -join ";"
                     $appASOwnerName=($owners.AdditionalProperties.appDisplayName) -join "|"
                    }
                    elseif (($owners.AdditionalProperties.servicePrincipalType) -and (!($owners.AdditionalProperties.userPrincipalName)))
                        { 
                        $appASOwner="YES"; 
                        $appASOwnerName=(($owners.AdditionalProperties | ? {$_.servicePrincipalType}).displayName) -join "|"
                        }
                    elseif 
                    ((!($owners.AdditionalProperties.servicePrincipalType)) -and (($owners.AdditionalProperties.userPrincipalName)))
                    {$upn=$owners.AdditionalProperties.userPrincipalName -join ";"}
                   }
            else {$upn="<<No Owner>>"}
        $entry=$app | Select CreatedDateTime,DisplayName,AppId,id,Notes,SignInAudience,       
        @{N="AppAsOwner";E={$appASOwner}},
        @{N="AppAsOwnerName";E={$appASOwnerName}},
        @{N="Owners";E={$upn}},
        @{N="OwnersCount";E={$owners.count}}
        $rawdata+=$entry
        $entry | Export-csv $mgAppsRegInventory -Append -NoTypeInformation               
} catch {
        Write-Host "$($Error[0].Exception)"        
        }
}

#-------------------------------------------------------------------------------------------
#           SERVICE PRINCIPAL/ENTERPRISE APP BLOCK
#-------------------------------------------------------------------------------------------

$EntRawData=Get-mgServicePrincipal -all
$asp=$EntRawData | select AccountEnabled,ServicePrincipalType,DisplayName,Id,AppId,DeletedDateTime,
@{N="CreatedDateTime";E={$(($_.AdditionalProperties.Values))}}

$entnewrawdata=@();$c=0
foreach ($entapp in $asp) {
$c++
$TA=CheckTokenAgeandReconnect
Write-Host "Fetching Owner:[TA=$TA]:[$c]:$($($entapp).id)"
$appASOwner="NO"
$appASOwnerName=@()
$upn=@()
try{
    $Owners=Get-mgServicePrincipalOwner -ServicePrincipalId $entapp.id -All -ea SilentlyContinue
    if ($owners){
                    if (($owners.AdditionalProperties.servicePrincipalType) -and ($owners.AdditionalProperties.userPrincipalName)){
                     $upn=$($owners.AdditionalProperties.userPrincipalName) -join ";"
                     $appASOwnerName=($owners.AdditionalProperties.appDisplayName) -join "|"
                    }
                    elseif (($owners.AdditionalProperties.servicePrincipalType) -and (!($owners.AdditionalProperties.userPrincipalName)))
                        { 
                        $appASOwner="YES"; 
                        $appASOwnerName=(($owners.AdditionalProperties | ? {$_.servicePrincipalType}).displayName) -join "|"
                        }
                    elseif 
                    ((!($owners.AdditionalProperties.servicePrincipalType)) -and (($owners.AdditionalProperties.userPrincipalName)))
                    {$upn=$owners.AdditionalProperties.userPrincipalName -join ";"}
                   }
    else {$upn="<<No Owner>>"}
   $SPAppRoleAssignedTolist=Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $entapp.id -All -ea SilentlyContinue        
}
catch{
     Write-Host "$($Error[0].Exception)"        
     #if ($($Error[0].Exception) -match "token has expired" ) {"Fetching new token.";ConnectMGGraph}
}

#change Guest account filture.
$hasguest=$SPAppRoleAssignedTolist | ? {$_.PrincipalType -eq "User"} | ? {$_.PrincipalDisplayName -notmatch $guestAccountNameFilture}
if ($hasGuest){$hg="YES";$GL=$hasguest.PrincipalDisplayName -join ";" }else{$hg="NO";$GL=@()}

#"Fetching user for app $($($entapp).id)"
$Entappdata=$entapp | select AccountEnabled,ServicePrincipalType,DisplayName,Id,AppId,CreatedDateTime,
@{N="AppAsOwner";E={$appASOwner}},
@{N="AppAsOwnerName";E={$appASOwnerName}},
@{N="OwnersCount";E={$Owners.Count}},
@{N="Owners";E={$upn}},
@{N="HasGuest";E={$HG}},
@{N="GuestID";E={$GL}},
@{N="GuestCount";E={($GL.count)}}

$Entappdata | Export-csv $mgEntAppsRegInventory -Append -NoTypeInformation
$EntNewRawData+=$Entappdata
}

$SPTypes=$asp | group ServicePrincipalType | select Name,Count
$EnabledEntApp=($asp | ? {$_.AccountEnabled -eq "True" -and $_.displayname -ne 'Workflow'}).count
$workflowCount=($asp | ? {$_.DisplayName -eq "Workflow"}).count
$disabledEntapp=($asp | ? {$_.AccountEnabled -ne "True"}).count
$appproxy=$EntRawData | ? {$_.Tags -Contains "WindowsAzureActiveDirectoryOnPremApp"}
$SAMLAPPS=$EntRawData | ? {$_.PreferredTokenSigningKeyThumbprint -ne $null}
$GuestAppCount=($entnewrawdata | ? {$_.HasGuest -eq "YES"}).count
$GuestAsOwner=($Rawdata | ? {$_.Owners -match "#EXT#"}).count
$reg1="interactiveUser=AF;servicePrincipal=AF;managedIdentity=AF;nonInteractiveUser=AF"
$ActiveAPPs=($Rawdata | ? {$_.notes -match "/"}).count

#----------------------------------------------------------------------------------------
# REPORT BODY
#----------------------------------------------------------------------------------------

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
  width: 25%;
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
<h2>Azure AD Applications and Service Principal Statistics</h2>
<div class="row">
  <div class="column" style="background-color:#33E3FF;">
    <h4>Application Registration</h4>
    <p>
       Total App=$($Applications.Count)</br>
       New app registered in Last 24 hours=$(($rawdata | ? {$_.CreatedDateTime -ge $((get-date).adddays(-1))}).count)</br>
       New app registered in Last 7 Days=$(($rawdata | ? {$_.CreatedDateTime -ge $((get-date).adddays(-7))}).count)</br>
       New app registered in Last 30 Days=$(($rawdata | ? {$_.CreatedDateTime -ge $((get-date).adddays(-30))}).count)
    </p> 
  </div>

  <div class="column" style="background-color:#DAF7A6;">
    <h4>App Registration Ownership analysis</h4>
    <p>0 Owner=$(($rawdata | ? {$_.OwnersCount -eq 0}).count)</br>
       1 Owner=$(($rawdata | ? {$_.OwnersCount -eq 1}).count)</br>
       2 Owner=$(($rawdata | ? {$_.OwnersCount -eq 2}).count)</br>
       3+ Owner=$(($rawdata | ? {$_.OwnersCount -ge 3}).count)</br>
   </p> 
  </div>

  <div class="column" style="background-color:#FFF933;">
    <h4>Enterprise App</h4>
    <p>Total Ent app=$($asp.count)</br> 
     Enabled apps=$EnabledEntApp</br>
     Workflow App=$workflowCount</br>
    Disabled Apps=$disabledEntapp</p>
  </div>
  <div class="column" style="background-color:#FF9033;">
    <h4>Ent App Types</h4>
    <p>Legacy=$(($SPTypes | ? {$_.name -eq "Legacy"}).Count)</br>
       ManagedIdentity=$(($SPTypes | ? {$_.name -eq "ManagedIdentity"}).Count) </br>
       Application=$(($SPTypes | ? {$_.name -eq "Application"}).Count) </br>
       SocialIdp=$(($SPTypes | ? {$_.name -eq "SocialIdp"}).Count)
    </p>
  </div>
</div>
</div>
  <div class="column" style="background-color:#ddd;">    
     <p>
        App Proxy =$($appproxy.count)</br>
        SAML Certs=$($SAMLAPPS.count)</br>
        App with Guest user=$GuestAppCount
    </p>
  </div>
  <div class="column" style="background-color:#ddd;">    
     <p>
        Apps With Guest As Owners=$GuestAsOwner</br>
        Total Apps with active Sign-ins=$ActiveAPPs        
    </p>
  </div>
</div>
</body>
</html>
"@
$bodyBox > $HTMLReport

$emailBody=(gc $HTMLReport | Out-String)
$attachment=$HTMLReport
$subject="AzureAD applications and Service Principal summary report"
Send-MailMessage -From $from -To $to -Subject $subject -Body $emailBody -BodyAsHtml -SmtpServer $smtp -Attachments $attachment
Stop-Transcript
