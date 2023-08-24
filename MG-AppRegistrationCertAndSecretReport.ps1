#-------------------------------------------------------------------------------------------------------
#Author:Sunil Chauhan
# 
#About: Fetch Azure App Client and script expiry details
#
#This script fetches all the Azure AD Apps and genrate report of the key and pass cred expiry status.
#Report Will be sent to azure AD support for further action.
#
#Ver: 2 - Converted to use graph api
#
############################################################################################-------------
#Change ME ###--
#email Config.
$from="Sunil@lab365.in"
$to="Sunil@lab365.in"
$smtp=<mysmtpsrv>

#dir Config
$reportLogPath="D:\AAD\Logs"
$reportPath="D:\AAD\Reports"

# Encrypted App Secret - export using SaveSecureString function in the scirpt
$secretPath="D:\AAD\secret.txt" 
#change ME end--

write-host "Starting transcript..."
Start-Transcript -Path $("$reportLogPath\GP_NE_certs_secrets$(get-date -f "dd-MM-yyyy").log")

#functions..
Function SaveSecureString {
param ($filename,$String)
$encryptedString = ConvertTo-SecureString -String $string -AsPlainText -Force | ConvertFrom-SecureString
$encryptedString >> $filename
}
Function decryptsecureString {
param($encryptDatafile)
$securestring = gc $encryptDatafile | ConvertTo-SecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securestring)
[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}
function GetJWTDetails{
param($token)
foreach ($i in 0..1) {
                      $data = $token.Split('.')[$i].Replace('-', '+').Replace('_', '/')
                      switch ($data.Length % 4) {
                          0 { break }
                          2 { $data += '==' }
                          3 { $data += '=' }
                      }
                  }

                  $decodedToken = [System.Text.Encoding]::UTF8.GetString([convert]::FromBase64String($data)) |
              ConvertFrom-Json
                  Write-Verbose "JWT Token:"
                  Write-Verbose $decodedToken

                  # Signature
                  foreach ($i in 0..2) {
                      $sig = $token.Split('.')[$i].Replace('-', '+').Replace('_', '/')
                      switch ($sig.Length % 4) {
                          0 { break }
                          2 { $sig += '==' }
                          3 { $sig += '=' }
                      }
                  }
                  Write-Verbose "JWT Signature:"
                  Write-Verbose $sig
                  $decodedToken | Add-Member -Type NoteProperty -Name "sig" -Value $sig

                  # Convert Expiry time to PowerShell DateTime
                  $orig = (Get-Date -Year 1970 -Month 1 -Day 1 -hour 0 -Minute 0 -Second 0 -Millisecond 0)
                  $timeZone = Get-TimeZone
                  $utcTime = $orig.AddSeconds($decodedToken.exp)
                  $offset = $timeZone.GetUtcOffset($(Get-Date)).TotalMinutes #Daylight saving needs to be calculated
                  $localTime = $utcTime.AddMinutes($offset)     # Return local time,

                  $decodedToken | Add-Member -Type NoteProperty -Name "expiryDateTime" -Value $localTime

                  # Time to Expiry
                  $timeToExpiry = ($localTime - (get-date))
                  $decodedToken | Add-Member -Type NoteProperty -Name "timeToExpiry" -Value $timeToExpiry

                  return $decodedToken
}
function connectMGGraph {
param($SecretFile)
$sec=decryptsecureString -encryptDatafile $SecretFile 
$secret=(ConvertTo-SecureString $sec -AsPlainText -Force)
$appID="59f6b285-5bb6-4b3a-91ed-5f40a03ee109"
$dirid="5d471751-9675-428d-917b-70f44f9630b0"
$AT=Get-MsalToken -ClientId $appID -ClientSecret $secret -TenantId $dirid
$AccessToken=$at.AccessToken
#GetJWTDetails -token $AccessToken | select -ExpandProperty roles
Connect-MgGraph -AccessToken $AccessToken # -Scopes "Application.Read.All"
#$applications=Get-MgApplication -All
}
############################ Report Name and Loations #############################################################

$NESecretPath="$reportPath\Near_expire_secret-$(get-date -f "dd-MM-yyyy").csv"
$NECertPath="$reportPath\Near_expire_cert-$(get-date -f "dd-MM-yyyy").csv"
$AECertPath="$reportPath\Already_expired_cert-$(get-date -f "MM-dd-yyyy").csv"
$AESecretPath="$reportPath\Already_expired_secret-$(get-date -f "MM-dd-yyyy").csv"

#- Yesterday's log file
del "$reportPath\Near_expire_secret-$((get-date).AddDays(-1).ToString("dd-MM-yyyy")).csv"
del "$reportPath\Near_expire_cert-$((get-date).AddDays(-1).ToString("dd-MM-yyyy")).csv"
#-----------------------------------

#duration
$Days=60
$now=get-date
#########-----------------------------------------------------------------------------------------------------------

Write-Host "Connecting to Microsoft Graph.."
connectMGGraph -SecretFile $secretPath

Write-Host "Fetching Azure AD Apps.."
$Applications=Get-MgApplication -All

Write-Host "Preparing report."
foreach ($app in $Applications) {
    $AppName = $app.DisplayName
    $AppID = $app.Id
    $ApplID = $app.AppId
    $secret = $App.PasswordCredentials
    $cert = $App.KeyCredentials

    foreach ($s in $secret) {
        $StartDate = $s.StartDateTime
        $EndDate = $s.EndDateTime
        $displayName=$s.DisplayName
        $keyid=$s.KeyId
        $operation = $EndDate - $now
        $ODays = $operation.Days
        $AlreadyExpired = "No"
        $x=$s.CustomKeyIdentifier
        $CustomKeyIdentifier=$Null
        if ($x){$CustomKeyIdentifier=[System.Convert]::ToBase64String($x)}
       #Near Expire
       if ([int]$ODays -le [int]$Days -and [int]$ODays -ge 0) {

                $Owner = (Get-MGApplicationOwner -ApplicationId $app.Id)             
                $Username = $Owner.AdditionalProperties.mail -join ";"
                $OwnerID = $Owner.ID -join ";"
                if ($owner.AdditionalProperties.mail -eq $Null) {
                   if (($Owner.id).count -gt 1){
                            #$Username = $Owner.AdditionalProperties.displayName + " **<This is an Application>**"
                            $s=Get-mgServicePrincipalOwner -ServicePrincipalId ($Owner.id)[0]
                            $Username=$s.AdditionalProperties.mail -join ";"
                        }
                    else
                        {
                        $s=Get-mgServicePrincipalOwner -ServicePrincipalId ($Owner.id)
                        $Username=$s.AdditionalProperties.mail -join ";"
                        }               
                
                }
                if ($Owner.AdditionalProperties.displayName -eq $null) {
                    $Username = "<<No Owner>>"
                }
                
                $Log = New-Object System.Object
                $Log | Add-Member -MemberType NoteProperty -Name "ToExpireInDays" -value $ODays
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $AppID
                $Log | Add-Member -MemberType NoteProperty -Name "KeyID" -Value $keyID
                $Log | Add-Member -MemberType NoteProperty -Name "Secret Start Date" -Value $StartDate
                $Log | Add-Member -MemberType NoteProperty -Name "Secret End Date" -value $EndDate
                $Log | Add-Member -MemberType NoteProperty -Name "SecretDisplayName" -Value $displayName
                $Log | Add-Member -MemberType NoteProperty -Name "CustomKeyIdentifier" -value $CustomKeyIdentifier
                $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
                $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID                
                $Log | export-csv -Path $NESecretPath -Append -NoTypeInformation
            }
   elseif ([int]$ODays -lt 0) {
              $Owner = (Get-MGApplicationOwner -ApplicationId $app.Id)               
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
                $Log | Add-Member -MemberType NoteProperty -Name "Secret Start Date" -Value $StartDate
                $Log | Add-Member -MemberType NoteProperty -Name "Secret End Date" -value $EndDate
                $Log | Add-Member -MemberType NoteProperty -Name "KeyID" -Value $keyID              
                $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
                $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID
                $Log | export-csv -Path $AESecretPath -Append -NoTypeInformation
            }        
    }

    foreach ($c in $cert) {
        $CStartDate = $c.StartDateTime
        $CEndDate = $c.EndDateTime
        $COperation = $CEndDate - $now
        $CODays = $COperation.Days
        $keyid=$c.KeyId
            if ([int]$CODays -le [int]$Days -and [int]$CODays -ge 0) {
                $Owner = (Get-MGApplicationOwner -ApplicationId $app.Id)               
                $Username = $Owner.AdditionalProperties.mail -join ";"
                $OwnerID = $Owner.ID -join ";"
                if ($owner.AdditionalProperties.mail -eq $Null) {
                    $Username = $Owner.AdditionalProperties.displayName + " **<This is an Application>**"
                }
                if ($Owner.AdditionalProperties.displayName -eq $null) {
                    $Username = "<<No Owner>>"
                }

                $Log = New-Object System.Object
                $Log | Add-Member -MemberType NoteProperty -Name "ToExpireInDays" -value $CODays
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $AppID
                $Log | Add-Member -MemberType NoteProperty -Name "KeyID" -Value $keyID
                $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $CStartDate
                $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $CEndDate
                $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
                $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID
                $Log | export-csv -Path $NECertPath -Append -NoTypeInformation
            }
            
            if ([int]$CODays -lt 0) {
             $Owner = (Get-MGApplicationOwner -ApplicationId $app.Id)               
                $Username = $Owner.AdditionalProperties.mail -join ";"
                $OwnerID = $Owner.ID -join ";"
                if ($owner.AdditionalProperties.mail -eq $Null) {
                    $Username = $Owner.AdditionalProperties.displayName + " **<This is an Application>**"
                }
                if ($Owner.AdditionalProperties.displayName -eq $null) {
                    $Username = "<<No Owner>>"
                }

                $Log = New-Object System.Object
                $Log | Add-Member -MemberType NoteProperty -Name "ExpiredDaysAgo" -value $CODays
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
                $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $AppID
                $Log | Add-Member -MemberType NoteProperty -Name "KeyID" -Value $keyID
                $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $CStartDate
                $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $CEndDate
                $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
                $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID
                $Log | export-csv -Path $AECertPath -Append -NoTypeInformation               
            }       
    }
}

#Non Owners Info
$NonOwnerSecret= ipcsv $NESecretPath | ? {$_.owner -match "No Owner"}
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
$p=$css + "<h4>Secret Near expery of applications without any owners</h4>"
$NonOwnerSecrethtml=$NonOwnerSecret | sort ToExpireInDays |select ToExpireInDays,ApplicationName,'Secret End Date',Owner | ConvertTo-Html -Fragment -PreContent $p
$appasowner= ipcsv $NESecretPath | ? {$_.owner -match "Application"} | sort ToExpireInDays |select ToExpireInDays,ApplicationName,'Secret End Date',Owner | ConvertTo-Html -Fragment 

$body=@"

<h3>AzureAD Applications Client & Secrets Analyses Report</h3>
<ul>
<li>Total Secrets to Expire in Next 60 Days     #$($(ipcsv $NESecretPath).count)</li>
<li>Total Certificate to Expire in Next 60 Days #$($(ipcsv $NECertPath).count) </li>
<li>Total Already Expired Secrets               #$($(ipcsv $AESecretPath).count)</li>
<li>Total Already Expired Certificates          #$($(ipcsv $AECertPath).count)</li>
</ul>

$NonOwnerSecrethtml

<p>
Thanks,</br>
AAD Support
</p>
"@
Write-Host "Sending report."
$subject="AzureAD App Client and secret expiring in next 60 days"
Send-MailMessage -From $from -To $to -Subject $subject -Attachments $AECertPath,$AESecretPath,$NESecretPath,$NECertPath -SmtpServer $smtp `
-Body $body -BodyAsHtml
echo "Done"
Stop-Transcript
