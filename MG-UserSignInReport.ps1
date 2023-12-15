#---------------------------------------------
# Get Azure AD User Sign In Info.
# Author: sunil Chauhan
# Email: Sunilkms@gmail.com
#---------------------------------------------
Write-host "Connect to Microsoft Graph."
$reportDir="D:\MyReports"
. "D:\MyReports\MainFunctions.ps1"
$SecretFile="D:\MyReports\secret.txt"
$appID="AppID"
$dirid="TenantID"
$AccessToken=FetchAccessToken -AppID $appID -DirID $dirid -secretFile $SecretFile -referesh
connectMGGraph -AccessToken $AccessToken

write-host "Fetching All synced Users."
$AllOSEUsers=Get-MgBetauser -Filter "UserType eq 'Member' and OnPremisesSyncEnabled eq true" -All -Property DisplayName,UserPrincipalName,
CreatedDateTime,PasswordPolicies,AccountEnabled,EmployeeType,OnPremisesLastSyncDateTime,ShowInAddressList,Department,SignInActivity

$c=0
$Result=@()
$date= get-date -Format dd-MM-yyyy-hh-mm
$reportName="$reportDir\SigninValidation_" + $date
foreach ($user in $AllOSEUsers){
$c++
$m=CheckTokenAgeandReconnect
Write-host "Fetching details[$c]-TA[$m]::$($user.UserPrincipalName)" -NoNewline

$data=$user | Select DisplayName,UserPrincipalName,
CreatedDateTime,PasswordPolicies,AccountEnabled,EmployeeType,OnPremisesLastSyncDateTime,ShowInAddressList,Department,SignInActivity

$cdt=Get-Date -Date $data.CreatedDateTime -Format dd-MM-yyy
$lst=Get-Date -Date $data.OnPremisesLastSyncDateTime -Format dd-MM-yyy
Write-Host " fetching Manager" -NoNewline
$owner=(Get-MgUserManager -UserId $user.id).AdditionalProperties.mail
write-host " Fetching signin logs."
$mguser=$data | select SignInActivity
$lsidt=$mguser.SignInActivity.LastSignInDateTime
$dago= ($lsidt - (get-date)).Days
$lnisidt=$mguser.SignInActivity.LastNonInteractiveSignInDateTime
$depart=$user | Select Department

if ( $lsidt -eq $null ){ $lsidt = "No interactive signin"}
else{
$lsidt=$mguser.SignInActivity.LastSignInDateTime.ToString('dd-MM-yyyy')
$lnisidt=$mguser.SignInActivity.LastNonInteractiveSignInDateTime.ToString('dd-MM-yyyy')
}

if ($lnisidt -eq $null) {$lnisidt = "No non-interactive signin"}
else {$lnisidt=$mguser.SignInActivity.LastNonInteractiveSignInDateTime.ToString('dd-MM-yyyy')}

$R=New-Object PSObject -property @{ 
"DisplayName"=$data.DisplayName
"UserPrincipalName"=$data.UserPrincipalName
"interactive-signIns"=$lsidt
"non-interactive"=$lnisidt
"CreationDate"=$cdt
"Department"=$depart.Department
"PasswordNeverExpires"= $data.PasswordPolicies
"AccountEnabled"=$data.AccountEnabled
"Owner"=$owner
"OnPremisesLastSyncDateTime"=$lst
"EmployeeType"=$data.EmployeeType
"Sign-In-DaysAgo"=$dago
}

$r | select CreationDate,OnPremisesLastSyncDateTime,EmployeeType,UserPrincipalName,DisplayName,AccountEnabled,
Owner,PasswordNeverExpires,Department,interactive-signIns, Sign-In-DaysAgo,non-interactive | Export-Csv "$ReportName.csv" -NoTypeInformation -Append
}
