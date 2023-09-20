# Author: Sunil Chauhan <sunilkms@gmail.com>
# Genrate report of the apps using AppProxy, and capture the SSL cert info
# script needs to connect both Graph and Azure AD powershell module.
#region - update me-------------------------

write-host "Starting transcript..."
$reportPAth="D:\MyScripts\Reports"
$reportLogPath="D:\MyScripts\Logs"
Start-Transcript -Path $("$reportLogPath\AppProxy_script-$(get-date -f "dd-MM-yyyy").log")
$reportName="$reportPAth\AppProxyReport-$(get-date -f "dd-MM-yyyy").csv"

# Email Info
$from="Sunil@lab365.in"
$to= "Sunil@lab365.in"
$smtp="smtp.lab365.in"
#endregion
#region--Support Functions
#graph api details
. "D:\MyScripts\MainFunctions.ps1"
$sec="D:\MyScripts\secret.txt"
$appID="APP ID"
$dirid="DIR ID"
$AccessToken=FetchAccessToken -AppID $appID -DirID $dirid -secretFile $sec -referesh
connectMGGraph -AccessToken $AccessToken
ConnectAzureAD
$AllServicePrincipal=Get-MgServicePrincipal -All:$true
$appproxy=$AllServicePrincipal | ? {$_.Tags -Contains "WindowsAzureActiveDirectoryOnPremApp"}

$now=get-date
$report=@()
foreach ($PApp in $appproxy){
$ssl=@()
$a=@()
$appid= "'" + $PApp.AppId + "'"
$dd=Get-MgApplication -Filter "appid eq $appID"
$AppConnector=(Get-AzureADApplicationProxyApplicationConnectorGroup -ObjectId $dd.Id).Name
$AppOwners=(Get-AzureADApplicationOwner -ObjectId $dd.Id).UserPrincipalName -join ";"
$a=Get-AzureADApplicationProxyApplication -ObjectId $dd.Id
$ssl=$a.VerifiedCustomDomainCertificatesMetadata
if ($ssl){$ToExpireInDays=($ssl.ExpiryDAte - $now).Days}else{$ToExpireInDays="NoSSLCertificate"}

 $report+=$PApp | select AppId,DisplayName,AccountEnabled,Homepage,
 @{N="ExternalAuthenticationType";E={$a.ExternalAuthenticationType}},
 @{N="SubjectName";E={$ssl.SubjectName}},
 @{N="AppRoleAsignmtReq";E={$PApp.AppRoleAssignmentRequired}},
 @{N="Thumbprint";E={$ssl.Thumbprint}},
 @{N="IssueDate";E={$ssl.IssueDate}},
 @{N="ExpiryDate";E={$ssl.ExpiryDate}},
 @{N="CertToExpireInDays";E={$ToExpireInDays}},
 @{N="AppConnector";E={$AppConnector}},
 @{N="Owners";E={$AppOwners}}
}
$report | export-csv $reportName -NoTypeInformation

$NECertPath=$report | ? {$_.CertToExpireInDays -lt 45 -and $_.CertToExpireInDays -notmatch "-"} | select DisplayName,CertToExpireInDays,ExpiryDate,Owners
$AECertPath=$report | ? {$_.CertToExpireInDays -match "-" } | select DisplayName,CertToExpireInDays,ExpiryDate,Owners

#html report
$NECH=$NECertPath | ConvertTo-Html -Fragment
$AECH=$AECertPath | ConvertTo-Html -Fragment

$css="<style>
table {font-family: arial, sans-serif;font-size: 12px;border-collapse: collapse;width: 100%;}
td, th {border: 0px solid #dddddd;text-align: left;padding: 6px;}
tr:nth-child(even){background-color: #f2f2f2;}
th {background-color: #7FFFD4;color: black;}
</style>
"

# Email Details

$subject="AzureAD AppProxy certificate usage summary report"
$body=@"
$css
<h4>AzureAD App Proxy Certificate usage Summary Report</h4>
<ul>
<li>Total App Enabled for AppProxy              #$($($appproxy).count) </li>
<li>Certificate to Expire in Next 45 Days #$($($NECertPath).count) </li>
<li>Already Expired Certificates          #$($($AECertPath).count)</li>
</ul>

<h4>Certificate to Expire in 45 days</h4>
<p> Notification is automated and is sent weekly to each app owner, please monitor support mailbox for owner responses.</p>
$NECH

<h4>Certificate already Expired</h4>
<p>Connect with the AppProxy App Owners and notify them for the Expired Certificates</p>
$AECH

<p>Thanks,</br>Sunil Chauhan</p>
"@

Send-mailmessage -From $from -to $to -Subject $subject -Smtp $smtp -Body $body -BodyAsHtml -Attachments $reportName

Stop-Transcript
