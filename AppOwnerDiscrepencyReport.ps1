#---------------------------------------------------------------------
# Compare the app owner in SP and Apps and genreate report.
# Owner Sync script will consume the input file genreated by this script.
#---------------------------------------------------------------------

#region - variables-------------------------
write-host "Starting transcript..."
$reportPAth="D:\MyScripts\Reports"
$reportLogPath="D:\MyScripts\Logs"

#Export Files
$ReportDir="D:\MyScripts\Reports\"
$OwCountMisMatchReportExportPath=$ReportDir + "OwnerDescrepencyBasedOnOwnerCount.csv"

#email info
$from="Sunil@lab365.in"
$to="Sunil@lab365.in"
$smtp="smtp.lab365.in"

Start-Transcript -Path $("$reportLogPath\MG_AppOwnerDiscrepencyReport-$(get-date -f "dd-MM-yyyy").log")

#Input Files to Import - genrated by the app summary report.
$mgAppsRegInventory="$reportPAth\MgAppsRegInventory-$(get-date -f "dd-MM-yyyy").csv"
$mgEntAppsInventory="$reportPAth\MgEntAppsInventory-$(get-date -f "dd-MM-yyyy").csv"

#ExportFile
$AppOwnersDiscrepency="$reportPAth\AppOwnersDiscrepency-$(get-date -f "dd-MM-yyyy").csv"
#endregion

$value="AppRegAppID;AppRegObjectId;AppRegDisplayname;AppRegOwnersCount;AppRegAppAsOwner;AppRegOwnerEmail;AppEntAppID;AppEntObjectID;AppEntDisplayname;AppEntOwnersCount;AppEntAppAsOwner;AppEntOwnerEmail"
Set-content -Path $AppOwnersDiscrepency -Value $value

$appsReg=import-csv $mgAppsRegInventory
$appsEnt=Import-Csv $mgEntAppsInventory | ? {$_.ServicePrincipalType -eq "Application"}
$c=0
foreach ($AppRegrec in $appsReg) #Appreg
{
$c++
$mappRegid=" "
$mownappreg=0
$mObjectIDappreg=" "
$mdispAppreg=" "
$mOwneremailReg=" "
$mAppRegAppAsOwner=""

$mappRegid=$AppRegrec.Appid
$mownappreg=$AppRegrec.OwnersCount
$mObjectIDappreg=$AppRegrec.Id
$mdispAppreg=$AppRegrec.displayname
$mAppRegAppAsOwner=$AppRegrec.AppAsOwnerName

Write-Host "Checking::[$c]#[$mdispAppreg]"
$AppEntrec=$appsEnt | ? {$_.appid -match $mappRegid}

if($AppEntrec)
	{  
	$mownappEnt=0
	$mappEntid=" "
	$mObjectIDappEnt=" "
	$mdispAppEnt=" "
	$mOwneremail=" "
	$mOwndispAppreg=" "
	$mOwndispAppEnt=" "

	$mappEntid=$AppEntrec.Appid
	$mownappEnt=$AppEntrec.OwnersCount
	$mObjectIDappEnt=$AppEntrec.Id
	$mdispAppEnt=$AppEntrec.DisplayName
  $mAppEntAppAsOwner=$AppEntrec.AppAsOwnerName

if($mappRegid -match $mappEntid){
		if($mownappreg -ge 1){$mOwneremailReg=$AppRegrec.Owners.split(";") -join "|"}  
		if($mownappEnt -ge 1){$mOwneremail=$Appentrec.Owners.split(";") -join "|"}
        $Value="$mappRegid;$mObjectIDappreg;$mdispAppreg;$mownappreg;$mAppRegAppAsOwner;$mOwneremailReg;$mappEntid;$mObjectIDappEnt;$mdispAppEnt;$mownappEnt;$mAppEntAppAsOwner;$mOwneremail"
		Add-content -Path $AppOwnersDiscrepency -Value $Value
		} 
	} 
} 

#region deep analysis-----

#import File
$DescrepencyReportPath=$ReportDir + "AppOwnersDiscrepency-$(get-date -f "dd-MM-yyyy").csv"

#Data Analysis
$Data=ipcsv $DescrepencyReportPath -Delimiter ";"
$OwnCountMisMatch=$data | ? {$_.AppRegOwnersCount -ne $_.AppEntOwnersCount}
$OwnCountMisMatch | Export-Csv -Path $OwCountMisMatchReportExportPath -NoTypeInformation -Force

$ocmh=$OwnCountMisMatch | select AppRegDisplayname,AppRegOwnersCount,AppEntOwnersCount | ConvertTo-Html -Fragment
$css="<style>
table {
  font-family: arial, sans-serif;
  font-size: 12px;
  border-collapse: collapse;
  width: 65%;
}

td, th {
  border: 1px solid #dddddd;
  text-align: left;
  padding: 6px;
}

tr:nth-child(even){background-color: #f2f2f2;}

th {
    background-color: #7FFFD4;
    color: black;
}
</style>"
#endregion--

#Send Report
$subject="App Owner Discrepency Report"
$body=@"
$css
<h4>App Owner Discrepency Report</h4>
<p>Please review the report, and sync app owners.</p>
$ocmh
<p>Thanks,</br>Sunil Chauhan</p>
"@
Send-mailmessage -From $from -to $to -Subject $subject -Smtp $smtp -attachments $OwCountMisMatchReportExportPath -Body $body -BodyAsHtml
Stop-Transcript
