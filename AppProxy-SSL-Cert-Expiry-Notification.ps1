#--- Update Me --------------------------------------------------------------------------------------------------------
$reportLogPath="D:\MyScripts\Logs"
Start-Transcript -Path $("$reportLogPath\AppProxy_SSL_Cert_Exp_Notification_script-$(get-date -f "dd-MM-yyyy").log")
$reportPAth="D:\MyScripts\Reports"
$reportName="$reportPAth\AppProxyReport-$(get-date -f "dd-MM-yyyy").csv"
#Email Info
$from="support.azuread@lab365.in"
$smtp="smtp.lab365.in"
#----------------------------------------------------------------------------------------------------------------------
$data= ipcsv $reportName

#filture expired and no ssl certs and no owner certs
$NoExpired=$data | ? {$_.CertToExpireInDays -notmatch "-|NoSSLCertificate"}
$NoExpired=$NoExpired | ? {$_.owners -ne ""}

#fetch certs about to be expied in next 30 days
$30=$NoExpired | ? {[int]$($_.CertToExpireInDays) -le 30}

#select certs going to expire in next 30,21,14, and 7 days.
$selectForComm=$30 | ? {$_.CertToExpireInDays -match "30|21|14" -or $_.CertToExpireInDays -eq 7}

#send Communication
if ($selectForComm) {
foreach ($app in $selectForComm) {
write-host "Sending Comm for [$($app.DisplayName)]::Owners::$($app.owners)"
$certhtm= $app | select DisplayName,Homepage,Thumbprint,ExpiryDate,CertToExpireInDays | ConvertTo-Html -Fragment

# Email Body HTML -- Modify accordingly.
$body=@"
<style>
table {font-family: arial, sans-serif;font-size: 12px;border-collapse: collapse;width: 100%;}
td, th {border: 0px solid #dddddd;text-align: left;padding: 6px;}
tr:nth-child(even){background-color: #f2f2f2;}
th {background-color: #7FFFD4;color: black;}
</style>
<p>Dear Application Owners,</br>
</br>
This email is from Azure AD Support Team. </br>
</br>
According to our system records, your Enterprise application (details mentioned below) is configured to use Azure AD Application Proxy.
</p>
$certhtm
<p>The application uses a SSL certificate which is going to expire soon, the Certificate is required to be renewed in advance to avoid any interruption to the service.</br>
</br>
In order to renew the certificate, please generate a new certificate and send us the certificate in .pfx format and its password secretly over the chat.</br>
</br>
Please feel free to contact us in case of any query.</br>
</br>
Thanks & Regards,</br>
Azure AD Support Team</p>
"@

$to=($app.Owners.split(";"))
$subject="ACTION NEEDED:Application Proxy certificate expiry notification"
Send-MailMessage -From $from -To $to -Cc $from -Subject $subject -Body $body -BodyAsHtml -SmtpServer $smtp
Stop-Transcript
}
}
