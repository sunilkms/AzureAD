#----------------------------------------------------------------------------
#Author: Sunilkms@gmail.com
#Automatically Clean Expired Secrets and certificats from the App.
#Secret and cert expired -gt 30 days will be removed. 
#----------------------------------------------------------------------------

#region-------------- Param -----------------------------------------
write-host "Starting transcript..."
$reportDir="D:\AADSupportScripts"
$reportPath="$reportDir\Reports"
$LogDirPath="$reportDir\Logs"
$expiredCertsDataFile="$reportPath\Already_expired_cert-$(get-date -f "MM-dd-yyyy").csv"
$ExpiredSecretsDataFile="$reportPath\Already_expired_secret-$(get-date -f "MM-dd-yyyy").csv"
$smtp="smtpServer"
$from="from@domain.com"
$to= "To@domain.com"
$subject="AzureAD Apps Certs and Secret removal execution Report"
$CredFile = "$reportDir\svcAccount@csa.mydomain.com.xml"
#---------------------------------------------------------------------
Start-Transcript -Path $("$LogDirPath\Expired_certs_and_secrets_Cleanup-$(get-date -f "dd-MM-yyyy").log")
#Remove Yesterday's File
#-------------------------------------------------------------------------------------------------

$YexpiredCertsDataFile="$reportPath\Already_expired_cert-$((get-date).AddDays(-1).ToString("MM-dd-yyyy")).csv"
$YExpiredSecretsDataFile="$reportPath\Already_expired_secret-$((get-date).AddDays(-1).ToString("MM-dd-yyyy")).csv"
del $YexpiredCertsDataFile,$YExpiredSecretsDataFile

#endregion
#region--------------Analyse Exported Report Data--------------

#This Script is dependent on "NE_ClientSecret_and_Certificates.ps1" for data export

Write-Host "Analysing Report cleanup certs.."
$expiredCertsData=ipcsv $expiredCertsDataFile
$expiredSecretsData=ipcsv $ExpiredSecretsDataFile

#fetch the secrets which have expired 30 day or more.
$SecretExpired30DaysOrMore=$expiredSecretsData | ? {$_.ExpiredDaysAgo -match "-"} | ? {[int]$_.ExpiredDaysAgo.trim("-") -gt [int]"30"}
$CertsExpired30DaysOrMore=$expiredCertsData | ? {$_.ExpiredDaysAgo -match "-"} |? {[int]$_.ExpiredDaysAgo.trim("-") -gt [int]"30"}
#endregion
#region-------------Connect to Azure AD------------------------------
Write-Host "Connecting to Azure AD.."
#Connect to Azure AD
Function LoadCredentials {
param($CredFile)
$CredFromFile = Import-Clixml $CredFile
$CredFromFile.password = $CredFromFile.Password | ConvertTo-SecureString
$Cred=New-Object system.Management.Automation.PSCredential($CredFromFile.username, $CredFromFile.password)
Set-Variable -Name Cred -Value $Cred -Scope 1
}

LoadCredentials -CredFile $CredFile
$sessionOption=Connect-AzureAD -Credential $Cred
#endregion--------------------------------------------------------------
#region---- Remove expired certs and secrets ------------------------
#Remove Certificats
$secretFailed=@()
$CertsFailed=@()
Write-Host "Total Certs to be removed:$($certsExpired30DaysOrMore.Count)"
if ($CertsExpired30DaysOrMore){
ForEach ($cert in $CertsExpired30DaysOrMore){
try {
sleep 1
Write-host "Removing Certid:($($cert.keyid)):EDA:[$($cert.ExpiredDaysAgo)]::from app=($($cert.ApplicationName))"
Remove-AzureADApplicationKeyCredential -ObjectId $cert.ApplicationID -KeyId $cert.keyid -ErrorAction SilentlyContinue
} catch {
#write-host "Failed to remove Cert with Exception:" $error[0].Exception
$CertsFailed+=$cert}}}

#Remove Secrets
Write-Host "Total Secret to be removed:$($SecretExpired30DaysOrMore.Count)"
if ($SecretExpired30DaysOrMore){
ForEach ($secret in $SecretExpired30DaysOrMore){
try{
sleep 1
Write-host "Removing secretid:($($secret.keyid)):|EDA[$($secret.ExpiredDaysAgo)]::from app=($($secret.ApplicationName))"
Remove-AzureADApplicationPasswordCredential -ObjectId $secret.ApplicationID -KeyId $secret.keyid -ErrorAction Ignore
} catch {
#write-host "Failed to remove Cert with Exception:" $error[0].Exception
$secretFailed+=$secret
}}}

$sh=$secretFailed | select ApplicationName,ExpiredDaysAgo,'Secret End Date',KeyID,Owner | ConvertTo-Html -Fragment
$ch=$CertsFailed | select ApplicationName,ExpiredDaysAgo,'Certificate End Date',KeyID,Owner | ConvertTo-Html -Fragment

if ($CertsFailed){
$chbody="<h4>Script could't remove the following Expired certs; Please remove manually.</h4>
$ch
"}

if ($secretFailed){
$shbody="<h4>Script could't remove the following Expired Secrets; Please remove manually.</h4>
$sh"}

$css="<style>
table {font-family: arial, sans-serif;font-size: 12px;border-collapse: collapse;width: 100%;}
td, th {border: 0px solid #dddddd;text-align: left;padding: 6px;}
tr:nth-child(even){background-color: #f2f2f2;}
th {background-color: #7FFFD4;color: black;}
</style>
"
$body=@"
$css
$chbody
$shbody
<p>Thanks,
</br>AAD Support</p>
"@

Send-mailmessage -From $from -to $to -Subject $subject -Smtp $smtp -Body $body -BodyAsHtml

Stop-Transcript
#endregion
