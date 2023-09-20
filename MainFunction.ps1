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

Function FetchAccessToken{
param([switch]$referesh=$false,$AppID,$DirID,$secretFile)
$sec=decryptsecureString -encryptDatafile $secretFile
$secret=(ConvertTo-SecureString $sec -AsPlainText -Force)
if ($referesh) {$AT=Get-MsalToken -ClientId $appID -ClientSecret $secret -TenantId $dirid -ForceRefresh}
else {$AT=Get-MsalToken -ClientId $appID -ClientSecret $secret -TenantId $dirid}
$at.AccessToken
#$at
}

Function ConnectMGGraph {
param($AccessToken)
$SecureAT=$($AccessToken | ConvertTo-SecureString -AsPlainText -Force)
Connect-MgGraph -AccessToken $SecureAT
}

Function GetJWTDetails{
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

Function CheckTokenAgeandReconnect {
$tokenage=(GetJWTDetails -token $AccessToken).timeToExpiry.Minutes
    if ($tokenage -lt 5) {
        $Global:AccessToken=fetchAccessToken -referesh -AppID $appID -DirID $dirid -secretFile $SecretFile
        ConnectMGGraph -AccessToken $AccessToken
        } else {$tokenage}
}

Function LoadCredentialsFromFile { 
param($XMLFile)
$CredFromFile = Import-Clixml $XMLFile
$CredFromFile.password = $CredFromFile.Password | ConvertTo-SecureString
$Cred=New-Object system.Management.Automation.PSCredential($CredFromFile.username, $CredFromFile.password)
Set-Variable -Name Cred -Value $Cred -Scope 1
}

Function ConnectAzureAD {
param($CredFile)
LoadCredentialsFromFile -XMLFile $credFile
$sessionOption=Connect-AzureAD -Credential $Cred
}
