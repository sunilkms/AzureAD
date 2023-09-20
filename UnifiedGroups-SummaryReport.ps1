#-----------------------------------------------------------------------------------------
#
#Author: Sunil Chauhan <sunilkms@gmail.com>
#About: Generate Unified Group Summary Report.
#
# Requirements: 1) MainFunction.ps1 script should be pre loaded.
#               2) save the secret as secure string.(function included in the mainFunction.ps1)  
#
#-----------------------------------------------------------------------------------------

#Adjust the following--
write-host "Starting transcript..."
$reportPAth="D:\MyScripts\Reports"
$reportLogPath="D:\MyScripts\Logs"

Start-Transcript -Path $("$reportLogPath\MG-Group-Summary-Report-$(get-date -f "dd-MM-yyyy").log")
$reportName="$reportPAth\MG-Group-Summary-Report-$(get-date -f "dd-MM-yyyy").csv"
$HTMLReport="$reportPAth\GroupSummaryReport.htm"

# MainFunction script location path.
. "D:\MyScripts\MainFunctions.ps1"

#email recipient information
$guestidentier='#EXT#@lab365-in.onmicrosoft.com'
$from="sunil@lab365.in"
$to="sunil@lab365.in"
$smtp="smtp.lab365.in"

#provide details
$SecretFile="D:\MyScripts\secret.txt"
$appID="<App ID>"
$dirid="<Dir ID>"

#------------------------------------------------------------------------------------------
Write-host "Connect to Microsoft Graph."

$AccessToken=FetchAccessToken -AppID $appID -DirID $dirid -secretFile $SecretFile -referesh
connectMGGraph -AccessToken $AccessToken

#Fetch Groups, Groups Members and Group Owners.
Write-Host "Fetching All Unified Groups."
$UnifiedGroup=Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All
write-host "Group data has been fetched, now fetching members and owners."
$c=0
$reportdata=@()
foreach ($group in $UnifiedGroup){

$c++
$tokenstatus=CheckTokenAgeandReconnect
Write-Host "Fetching Group Details#[$c]#[$tokenstatus]#$($group.displayName)"
$groupMember=(Get-MgGroupMember -GroupId $group.Id -All)
$GroupOwner=(Get-MgGroupOwner -GroupId $Group.Id -All)
$gm=$groupMember.AdditionalProperties.userPrincipalName -join ";"
$ToExpireInDays=($group.ExpirationDateTime - $(get-date)).Days

if($gm -match $guestidentier){$hasGuest="YES"} else {$hasGuest="NO"}
if($GroupOwner.count -lt 2){$GO=$GroupOwner.AdditionalProperties.userPrincipalName -join ";"}else{$GO=@()}

$GD=$group | select id,Classification,DisplayName,mail,CreatedDateTime,RenewedDateTime,ExpirationDateTime,
@{N="ToExpireInDays";E={$ToExpireInDays}},
SecurityEnabled,Visibility,
@{N="resourceProvisioningOptions";E={$_.AdditionalProperties.resourceProvisioningOptions}},
@{N="GroupMemebersCount";E={$groupMember.count}},
@{N="HasGuest";E={$hasGuest}},
@{N="GroupOwnersCount";E={$GroupOwner.count}},
@{N="GroupOwners";E={$GO}}
$reportdata+=$GD
$GD | export-csv -Path $reportName -NoTypeInformation -Append
}

Write-Host "Analysing data."
$0Own0Mem=$(($reportdata | ? {$_.GroupOwnersCount -eq 0 -and $_.GroupMemebersCount -eq 0}))
$0Own1Mem=$(($reportdata | ? {$_.GroupOwnersCount -eq 0 -and $_.GroupMemebersCount -eq 1}))
$0Own2to12Mem=@(); 2..12 | %  {$n=$_; $0Own2to12Mem+=$(($reportdata | ? {$_.GroupOwnersCount -eq 0 -and $_.GroupMemebersCount -eq $n}))}
$0OwnGt12Mem=$(($reportdata | ? {$_.GroupOwnersCount -eq 0 -and $_.GroupMemebersCount -gt 12}))

$0Own0Mem | Export-Csv -Path "$reportPAth/No_Owner_No_Members_Groups.csv" -NoTypeInformation
$0Own1Mem | Export-Csv -Path "$reportPAth/No_Owner_1_Members_Groups.csv" -NoTypeInformation
$0Own2to12Mem | Export-Csv -Path "$reportPAth/No_Owner_2_to_12_Members_Groups.csv" -NoTypeInformation
#$0OwnGt12Mem | Export-Csv -Path "$reportPAth/No_Owner_gt_12_Members_Groups.csv" -NoTypeInformation

write-host "Preparing body"
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
<h2>Office 365 Group Summary Report</h2>
<div class="row">
  
  <div class="column" style="background-color:#33E3FF;">
    <h4>Unified Group Summary</h4>
    <p>
       Total Unified Groups=$($reportdata.Count)</br>
       Created in Last 24 hours=$(($reportdata | ? {$_.CreatedDateTime -ge $((get-date).adddays(-1))}).count)</br>
       Created in Last 7 Days=$(($reportdata | ? {$_.CreatedDateTime -ge $((get-date).adddays(-7))}).count)</br>
       Created in Last 30 Days=$(($reportdata | ? {$_.CreatedDateTime -ge $((get-date).adddays(-30))}).count)
    </p> 
  </div>

  <div class="column" style="background-color:#DAF7A6;">
    <h4>Unified Groups Ownership Analysis</h4>
    <p>
        0 Owner=$(($reportdata | ? {$_.GroupOwnersCount -eq 0}).count)</br>
        1 Owner=$(($reportdata | ? {$_.GroupOwnersCount -eq 1}).count)</br>
        2 Owner=$(($reportdata | ? {$_.GroupOwnersCount -eq 2}).count)</br>
        3+ Owner=$(($reportdata | ? {$_.GroupOwnersCount -ge 3}).count)</br>
   </p> 
  </div>

  <div class="column" style="background-color:#FFF933;">
    <h4>0 Owner Group Analysis</h4>
    <p>
     0 Owner and 0 Member=$($0Own0Mem.count)</br> 
     0 Owner but 1 Member=$($0Own1Mem.count)</br>
     0 Owner but 2 to 12 members=$($0Own2to12Mem.count)</br>
     0 Owners but > 12 members=$($0OwnGt12Mem.count)
   </p>
  </div>

  <div class="column" style="background-color:#FF9033;">
    <h4>Group Expiration Analyses</h4>
    <p>
       Groups to expire in next 7 days=$(($reportdata | ? {$_.ToExpireInDays -le 7}).count)</br>
       Groups to expire in next 15 days=$(($reportdata | ? {$_.ToExpireInDays -le 15}).count)</br>
       Groups to expire in next 30 days=$(($reportdata | ? {$_.ToExpireInDays -le 30}).count)</br> 
       Groups has Guests=$(($reportdata | ? {$_.HasGuest -eq "YES"}).Count)</br>      
    </p>
  </div>
</div>
</div>  
</div>
</body>
</html>
"@
$bodyBox > $HTMLReport
Write-Host "Sending reporting."

$emailBody=(gc $HTMLReport | Out-String)
$attachment=$HTMLReport,"$reportPAth/No_Owner_No_Members_Groups.csv","$reportPAth/No_Owner_1_Members_Groups.csv","$reportPAth/No_Owner_2_to_12_Members_Groups.csv"
$subject="Office 365 Groups Summary report"
Send-MailMessage -From $from -To $to -Subject $subject -Body $emailBody -BodyAsHtml -SmtpServer $smtp -Attachments $attachment
"Done"
Stop-Transcript
