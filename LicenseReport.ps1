#--------------------------------------------------------
# O365 License SKU Report
# Author: Sunil Chauhan
# Email: Sunilkms@gmail.com
# Change Report Recipients and app information, side load the mail function script.
# -------------------------------------------------------

$to="sunil@lab365.in"
$from="sunil@lab365.in"
$smtp= "Smtpserver"

Write-host "Connect to Microsoft Graph."
$reportDir="D:\MyScript"
. "D:\MyScripts\MainFunctions.ps1"
$SecretFile="D:\MyScripts\secret.txt"
$appID="AppID"
$dirid="Tenant ID"
$AccessToken=FetchAccessToken -AppID $appID -DirID $dirid -secretFile $SecretFile -referesh
connectMGGraph -AccessToken $AccessToken

$CSS="<style>
table {
  font-family: arial, sans-serif;
  font-size: 13px;
  border-collapse: collapse;
  width: 45%;
}

td, th {
  border: 1px solid #dddddd;
  text-align: left;
  padding: 2px;
}

tr:nth-child(even){background-color: #f2f2f2;}

th {
    background-color: #7FFFD4;
    color: black;
}
</style>"
Function Set-CellColor {   <#
        Syntax
        <Property Name> <Operator> <Value>
        
        <Property Name>::= the same as $Property.  This must match exactly
        <Operator>::= "-eq" | "-le" | "-ge" | "-ne" | "-lt" | "-gt"| "-approx" | "-like" | "-notlike" 
            <JoinOperator> ::= "-and" | "-or"
            <NotOperator> ::= "-not"
        
    .EXAMPLE
        get-process | convertto-html | set-cellcolor -Propety cpu -Color red -Filter "cpu -gt 1000" | out-file c:\test\get-process.html
        Assuming Set-CellColor has been dot sourced, run Get-Process and convert to HTML.  
        Then change the CPU cell to red only if the CPU field is greater than 1000.
        
    .EXAMPLE
        get-process | convertto-html | set-cellcolor cpu red -filter "cpu -gt 1000 -and cpu -lt 2000" | out-file c:\test\get-process.html
        
    .EXAMPLE
        $HTML = $Data | sort server | ConvertTo-html -head $header | Set-CellColor cookedvalue red -Filter "cookedvalue -gt 1"
        PS C:\> $HTML = $HTML | Set-CellColor Server green -Filter "server -eq 'dc2'"
        PS C:\> $HTML | Set-CellColor Path Yellow -Filter "Path -like ""*memory*""" | Out-File c:\Test\colortest.html
        
        
    .EXAMPLE
        $HTML = $Data | sort server | ConvertTo-html -head $header | Set-CellColor cookedvalue red -Filter "cookedvalue -gt 1" -Row
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,Position=0)]
        [string]$Property,
        [Parameter(Mandatory,Position=1)]
        [string]$Color,
        [Parameter(Mandatory,ValueFromPipeline)]
        [Object[]]$InputObject,
        [Parameter(Mandatory)]
        [string]$Filter,
        [switch]$Row
    )  
    Begin {
        Write-Verbose "$(Get-Date): Function Set-CellColor begins"
        If ($Filter)
        {   If ($Filter.ToUpper().IndexOf($Property.ToUpper()) -ge 0)
            {   $Filter = $Filter.ToUpper().Replace($Property.ToUpper(),"`$Value")
                Try {
                    [scriptblock]$Filter = [scriptblock]::Create($Filter)
                }
                Catch {
                    Write-Warning "$(Get-Date): ""$Filter"" caused an error, stopping script!"
                    Write-Warning $Error[0]
                    Exit
                }
            }
            Else
            {   Write-Warning "Could not locate $Property in the Filter, which is required.  Filter: $Filter"
                Exit
            }
        }
    }
    Process {
        $InputObject = $InputObject -split "`r`n"
        ForEach ($Line in $InputObject)
        {   If ($Line.IndexOf("<tr><th") -ge 0)
            {   Write-Verbose "$(Get-Date): Processing headers..."
                $Search = $Line | Select-String -Pattern '<th ?[a-z\-:;"=]*>(.*?)<\/th>' -AllMatches
                $Index = 0
                ForEach ($Match in $Search.Matches)
                {   If ($Match.Groups[1].Value -eq $Property)
                    {   Break
                    }
                    $Index ++
                }
                If ($Index -eq $Search.Matches.Count)
                {   Write-Warning "$(Get-Date): Unable to locate property: $Property in table header"
                    Exit
                }
                Write-Verbose "$(Get-Date): $Property column found at index: $Index"
            }
            If ($Line -match "<tr( style=""background-color:.+?"")?><td")
            {   $Search = $Line | Select-String -Pattern '<td ?[a-z\-:;"=]*>(.*?)<\/td>' -AllMatches
                $Value = $Search.Matches[$Index].Groups[1].Value -as [double]
                If (-not $Value)
                {   $Value = $Search.Matches[$Index].Groups[1].Value
                }
                If (Invoke-Command $Filter)
                {   If ($Row)
                    {   Write-Verbose "$(Get-Date): Criteria met!  Changing row to $Color..."
                        If ($Line -match "<tr style=""background-color:(.+?)"">")
                        {   $Line = $Line -replace "<tr style=""background-color:$($Matches[1])","<tr style=""background-color:$Color"
                        }
                        Else
                        {   $Line = $Line.Replace("<tr>","<tr style=""background-color:$Color"">")
                        }
                    }
                    Else
                    {   Write-Verbose "$(Get-Date): Criteria met!  Changing cell to $Color..."
                        $Line = $Line.Replace($Search.Matches[$Index].Value,"<td style=""background-color:$Color"">$Value</td>")
                    }
                }
            }
            Write-Output $Line
        }
    }
    End {
        Write-Verbose "$(Get-Date): Function Set-CellColor completed"
    }
}

$sku=Get-MgSubscribedSku
#$sku | Select-Object @('SkuPartNumber','SkuId','ServicePlans','ConsumedUnits') -ExpandProperty 'PrepaidUnits'
$licr=$sku | Select SkuPartNumber,CapabilityStatus,AppliesTo,
@{N="TotalUnits";e={$($_.PrepaidUnits.Enabled)}},
ConsumedUnits, #{$_.PrepaidUnits.Enabled},
@{N="AvailableUnits";E={$($_.PrepaidUnits.Enabled - $_.ConsumedUnits)}},
@{N="AU%";E={$d=(100 - ($_.ConsumedUnits/$_.PrepaidUnits.Enabled)*100);[math]::Round($d,2)}} `
| sort ConsumedUnits -Descending | ? {$_.ConsumedUnits -gt 0}

#$allsku | ft

$bb=$licr | ? {$_.SkuPartNumber -match "pack|ENTERPRISEPREMIUM"}
$aa=$licr | ? {$_.SkuPartNumber -notmatch "pack|ENTERPRISEPREMIUM"}
$cc=($BB+=$aa)
$licrhtml=$cc | ConvertTo-HTML -Fragment `
-PreContent "
$CSS 
<h3>Please check the depleted units.</h3></br>" `
-PostContent "</br>Thanks,</p>Sunil Chauhan"

#$data=$licrhtml | set-cellcolor AU% GreenYellow -filter "AU% -gt 15"
$data=$licrhtml | set-cellcolor AvailableUnits GreenYellow -filter "AvailableUnits -gt 50"
#$data=$data | set-cellcolor AvailableUnit orange -filter "AvailableUnit -lt 70"
$data=$data | set-cellcolor AvailableUnits LightCoral -filter "AvailableUnits -lt 50"
#$data=$data | set-cellcolor AvailableUnit LightCoral -filter "AvailableUnit -lt 35"

$body=@"
$data
"@

$trigger=$licr | ? {
$_.SkuPartNumber -match "ENTERPRISEPACK" -or 
$_.SkuPartNumber -match "STANDARDPACK" -or
$_.SkuPartNumber -match "ENTERPRISEPREMIUM" -or
$_.SkuPartNumber -match "MCOEV" -or
$_.SkuPartNumber -match "MEETING_ROOM" -or
$_.SkuPartNumber -match "PHONESYSTEM_VIRTUALUSER"
}

if($trigger){
if ($trigger.AvailableUnits -lt 40) {
$subject="License report:ATTENTION NEEDED"
Send-MailMessage -From $from -To $to -Subject $subject -Smtpserver $smtp -body $body -BodyAsHtml 
}
Else {
$subject="License report:All OK"
Send-MailMessage -From $from -To $to -Subject $subject -Smtpserver $smtp -body $body -BodyAsHtml 
}
}
