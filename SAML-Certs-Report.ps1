#
# Author: Sunil Chauhan <sunilkms@gmail.com>
# Genrate report of the all apps using saml certs along with their expeiry information
#
#region - Dynamic variables-------------------------
write-host "Starting transcript..."
$reportPAth="D:\MyScripts\Reports"
$reportLogPath="D:\MyScripts\Logs"
Start-Transcript -Path $("$reportLogPath\SAML_certs_script-$(get-date -f "dd-MM-yyyy").log")

#recipients Details
$from="sunil@lab365.in"
$to="sunil@lab365.in"
$SMTP="<my smtp server>"

#microsoft notify about the saml cert expeiration, it a good idea to add the support email address as well to track these notification
# this variable can capture if the notification email address is available on the cert entry.
# update your support email address below.
$supportEmail="support.azuread@lab365.in"

#endregion
#region--Support Functions
#graph api details
. "D:\MyScrupts\MainFunctions.ps1"
$Secret="D:\MyScripts\secret.txt"
$appID="APP ID"
$dirid="DIR ID"
$AccessToken=FetchAccessToken -AppID $appID -DirID $dirid -secretFile $Secret
connectMGGraph -AccessToken $AccessToken

#region-- fetch SP ----
$AllServicePrincipal=Get-MgServicePrincipal -All:$true 
$samlEnabledApps= $AllServicePrincipal | ? {$_.PreferredTokenSigningKeyThumbprint -ne $null}
#$samlEnabledApps= $AllServicePrincipal | ? {$_.PreferredSingleSignOnMode -eq "saml"}
$now= get-date
$Days=3000
$SamlReportFile="$reportPAth\SP_Enabled_with_SAML_Cert-$(get-date -f dd-MM-yyyy).csv"
$SamlReportExpFile="$reportPAth\SP_Enabled_with_SAML_Cert_already_expired-$(get-date -f dd-MM-yyyy).csv"
$SamlReportnonotemailFile="$reportPAth\SP_Enabled_with_SAML_Cert_No_notification_email-$(get-date -f dd-MM-yyyy).csv"

$V1=@()
$V2=@()

#$sssssss=$samlEnabledApps[0..50]
foreach ($app in $samlEnabledApps) {

    $AppName = $app.DisplayName
    $AppID = $app.Id
    $ApplID = $app.AppId
    $secret = $App.PasswordCredentials
    $notifyEmailAddress=$app.NotificationEmailAddresses -join ";"

    write-host "Processing::$AppName "

    foreach ($s in $secret) {
        $StartDate = $s.StartDateTime
        $EndDate = $s.EndDateTime
        $displayName=$s.DisplayName
        $keyid=$s.KeyId
        $operation = $EndDate - $now
        $ODays = $operation.Days
        $AlreadyExpired = "No"

        #$x=$s.CustomKeyIdentifier
        #$CustomKeyIdentifier=$Null
        #if ($x){$CustomKeyIdentifier=[System.Convert]::ToBase64String($x)}

       #Near Expire
       if ([int]$ODays -le [int]$Days -and [int]$ODays -ge 0) {
                "Write-host Fetching Owner.."
                $Owner=(Get-mgServicePrincipalOwner -ServicePrincipalId $AppID)               
                $Username=$Owner.AdditionalProperties.mail -join ";"
                              
                if ($owner.AdditionalProperties.mail -eq $Null) {
                    $Username = $Owner.AdditionalProperties.displayName + " **<This is an Application>**"
                }
                if ($Owner.AdditionalProperties.displayName -eq $null) {
                    $Username = "<<No Owner>>"
                }
                
                $Log = New-Object System.Object
                $Log | Add-Member -MemberType NoteProperty -Name "ToExpireInDays" -value $ODays
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $AppID
                $Log | Add-Member -MemberType NoteProperty -Name "KeyID" -Value $keyID
                $Log | Add-Member -MemberType NoteProperty -Name "SAMLStartDate" -Value $StartDate
                $Log | Add-Member -MemberType NoteProperty -Name "SAMLEndDate" -value $EndDate
                $Log | Add-Member -MemberType NoteProperty -Name "SecretDisplayName" -Value $displayName
                $Log | Add-Member -MemberType NoteProperty -Name "NotificationEmailAddresses" -value $notifyEmailAddress
                $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username             
                $v1+=$log
                #$Log | export-csv -Path $SamlReportFile -Append -NoTypeInformation
            }
   elseif ([int]$ODays -lt 0) {
                
               #$Owner = (Get-MGApplicationOwner -ApplicationId $app.Id)               
                $Username = $Owner.AdditionalProperties.mail -join ";"
                $OwnerID = $Owner.ID -join ";"
                if ($owner.AdditionalProperties.mail -eq $Null) {
                    $Username = $Owner.AdditionalProperties.displayName + " **<This is an Application>**"
                }
                if ($Owner.AdditionalProperties.displayName -eq $null) {
                    $Username = "<<No Owner>>"
                }

                $Log = New-Object System.Object 
                $Log | Add-Member -MemberType NoteProperty -Name "ExpiredDaysAgo" -value $ODays   
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $AppID
                $Log | Add-Member -MemberType NoteProperty -Name "SAMLStartDate" -Value $StartDate
                $Log | Add-Member -MemberType NoteProperty -Name "SAMLEndDate" -value $EndDate
                $Log | Add-Member -MemberType NoteProperty -Name "KeyID" -Value $keyID
                #$Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $Null
                $Log | Add-Member -MemberType NoteProperty -Name "NotificationEmailAddresses" -value $notifyEmailAddress
                $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username            
                #$Log | export-csv -Path $SamlReportExpFile -Append -NoTypeInformation
                $V2+=$Log
            }        
    }
}

#$v1 | ? {$_.ToExpireInDays -le 60} | select ApplicationName,ToExpireInDays,SAMLEndDate
$appswithoutnotificationemails=$v1 | ? {$_.NotificationEmailAddresses -notmatch $supportEMail}
$appswithoutnotificationemails | Export-csv $SamlReportnonotemailFile -NoTypeInformation
$V2 | Export-Csv $SamlReportExpFile -NoTypeInformation

#endregion
#region -- Send Report ---
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
$p=$css + "<h4>SAML Enabled Service Principals Report</h4>"
$NonOwnerSecrethtml=$v1 | ? {$_.ToExpireInDays -le 60} | select ApplicationName,ToExpireInDays,SAMLEndDate,NotificationEmailAddresses,Owner | ConvertTo-Html -Fragment -PreContent $p
#$appasowner= ipcsv $NESecretPath | ? {$_.owner -match "Application"} | sort ToExpireInDays |select ToExpireInDays,ApplicationName,'Secret End Date',Owner | ConvertTo-Html -Fragment 

$body=@"

<h3>AzureAD SAML Enabled Service Principals Report</h3>
<p> 

Total SAML Enabled Apps:$(($samlEnabledApps).count)</p>
<h4>SAML Cert to expire in next 60 days</h4>
$NonOwnerSecrethtml

Thanks,</br>
Sunil Chauhan
</p>

"@
Write-Host "Sending report."
$subject="AzureAD SAML Enabled Service Principals Report"
Send-MailMessage -From $from -To $to -Subject $subject -Attachments $SamlReportExpFile,$SamlReportnonotemailFile  -SmtpServer $SMTP `
-Body $body -BodyAsHtml
echo "Done"
Stop-Transcript
#endregion
