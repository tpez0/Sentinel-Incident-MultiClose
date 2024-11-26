 #-------------------------------------------------------------------------------------
 # Script: Sentinel-Incident-MultiClose.ps1
 # Author: tpez0
 # Notes : No warranty expressed or implied.
 #         Use at your own risk.
 #
 # Function: Simple tool to close multiple Azure Sentinel Incidents
 #           selected by Incident Severity
 #              
 #--------------------------------------------------------------------------------------

# Create connection to Azure Account
Write-Host "Connecting Azure Account..." -ForegroundColor Magenta
Connect-AzAccount | out-null
Clear-Host
  
# Loading available Resource Groups, listing in a simple menu and asking for input
Write-Host "Loading available Resource Groups..." -ForegroundColor Magenta
$RGList = @(Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName -Unique)
$i = 0
foreach ($RGItem in $RGList){
    Write-Host [$i] "|" $RGItem
    $i++
}
$RGNum = $(Write-Host Enter Resource Group number: [0-$i] " " -ForegroundColor Yellow -NoNewline; Read-Host)
Clear-Host

# Loading available Wokspace in selected Resource Group, listing in a simple menu and asking for input
Write-Host "Loading available Workspace..." -ForegroundColor Magenta
$ResList = @(Get-AzResource -ResourceGroupName $RGList[$RGNum] | Select-Object -ExpandProperty Name -Unique)
$i = 0
foreach ($ResItem in $ResList){
    Write-Host [$i] "|" $ResItem
    $i++
}
$WSNum = $(Write-Host Enter Workspace number: [0-$i] " " -ForegroundColor Yellow -NoNewline; Read-Host)
Clear-Host

# Loading current user information
$OwnerEmail = (Get-AzContext).Account.Id
$Owner = (Get-AzADUser -UserPrincipalName $OwnerEmail).DisplayName

# Asking for the amount of days to close
# For example: if 3 is selected, three days will be deleted from today
$Days = $(Write-Host 'Enter the amount of days to close: [1-90] ' -ForegroundColor Yellow -NoNewline; Read-Host)
Clear-Host

# Loading menu listing Incident Severity, asking the user and validating input
Write-Host ""
Write-Host "[ 0 ] | Informational" -ForegroundColor Yellow
Write-Host "[ 1 ] | Low" -ForegroundColor Yellow
Write-Host "[ 2 ] | Medium" -ForegroundColor Yellow
Write-Host "[ 3 ] | High" -ForegroundColor Yellow
Write-Host "[ X ] | All" -ForegroundColor Yellow
Write-Host "[ ALL ] | All except High" -ForegroundColor DarkYellow
$SeverityNum = $(Write-Host 'Enter Severity to close: [ 0-3 | X | ALL ] ' -ForegroundColor Yellow -NoNewline; Read-Host)
Clear-Host

switch ($SeverityNum) {
    '0' {$Severity = "Informational"}
    '1' {$Severity = "Low"}
    '2' {$Severity = "Medium"}
    '3' {$Severity = "High"}
    'ALL' {$Severity = "All except High"}
    'X' {$Severity = "All"}
    Default {$Severity = "All except High"}
}
    
    # A summary will be created in order to review all the selections and decide to continue or exit
    Write-Host "Selected Resource Group: " -NoNewline -ForegroundColor Green; $RGList[$RGNum]
    Write-Host "Selected Workspace: " -NoNewline -ForegroundColor Green; $ResList[$WSNum]
    Write-Host "Owner Email: " -NoNewline -ForegroundColor Green; $OwnerEmail
    Write-Host "Owner Display Name: " -NoNewline -ForegroundColor Green; $Owner
    Write-Host "Selected Severity: " -NoNewline -ForegroundColor Green; $Severity
    # If selected Severity is HIGH, show the selected title and Classification Comment
    if ($SeverityNum -eq '3'){
        Clear-Host
            Write-Host "Loading available High Severity Incidents Titles" -ForegroundColor Magenta
            Write-Host "It takes a lot of time. Let's have a coffee!" -ForegroundColor Red
            $HighTitleList = @(Get-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] | where { ($_.Status -eq "New" -and $_.CreatedTimeUtc -gt (Get-Date).AddDays(-$Days) -and $_.Severity -eq "High")} | Select-Object -ExpandProperty Title -Unique
            )
            $i = 0
            foreach ($HighTitle in $HighTitleList){
                Write-Host [$i] "|" $HighTitle
                $i++
            }
        $HighTitleNum = $(Write-Host Enter Incident Title: [0-$i] " " -ForegroundColor Yellow -NoNewline; Read-Host)
        $HighComment = $(Write-Host 'Enter classification comment for High Severity Incidents: ' -ForegroundColor Yellow -NoNewline; Read-Host)

        Write-Host "Selected Resource Group: " -NoNewline -ForegroundColor Green; $RGList[$RGNum]
        Write-Host "Selected Workspace: " -NoNewline -ForegroundColor Green; $ResList[$WSNum]
        Write-Host "Owner Email: " -NoNewline -ForegroundColor Green; $OwnerEmail
        Write-Host "Owner Display Name: " -NoNewline -ForegroundColor Green; $Owner
        Write-Host "Selected Severity: " -NoNewline -ForegroundColor Green; $Severity
        Write-Host "      Selected High Severity incidents: " -NoNewline -ForegroundColor Green; $HighTitleList[$HighTitleNum]; Write-Host "      Classification Comment: " -NoNewline -ForegroundColor Green; $HighComment
        }

    
    Write-Host "Bulk close from selected date: " -NoNewline -ForegroundColor Green; (Get-Date).AddDays(-$Days)
    
    # The script is ready to run. Press any key to continue or Q to disconnect and exit
    $PAUSE = $(Write-Host 'Press any key to continue or "Q" to abort: ' -ForegroundColor Yellow -NoNewline; Read-Host)
    if ($PAUSE -eq "Q"){Write-Host " " -ForegroundColor Red; Write-Host "Disconnecting from Azure" -ForegroundColor Red; Disconnect-AzAccount; Exit
}
    Clear-Host


If ($Severity -eq "Informational"){
    Get-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum]
    | where {
            ($_.Status -eq "New" -and 
            $_.CreatedTimeUtc -gt (Get-Date).AddDays(-$Days) -and 
            $_.Severity -eq $Severity)
            } 
            | ForEach-Object {Update-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -Status Closed -Title $_.Title -Id $_.Name -Severity $_.Severity -OwnerAssignedTo $Owner -OwnerEmail $OwnerEmail -Classification BenignPositive -ClassificationReason SuspiciousButExpected}
}
    
If ($SeverityNum -eq "1"){

    Get-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -ErrorAction Stop
    | where {
            ($_.Status -eq "New" -and 
            $_.CreatedTimeUtc -gt (Get-Date).AddDays(-$Days) -and 
            $_.Severity -eq $Severity)
            } 
            | ForEach-Object {Update-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -Status Closed -Title $_.Title -Id $_.Name -Severity $_.Severity -OwnerAssignedTo $Owner -OwnerEmail $OwnerEmail -Classification BenignPositive -ClassificationReason SuspiciousButExpected}
}
    
If ($SeverityNum -eq "2"){
    Get-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -ErrorAction Stop
    | where {
            ($_.Status -eq "New" -and 
            $_.CreatedTimeUtc -gt (Get-Date).AddDays(-$Days) -and 
            $_.Severity -eq $Severity)
            } 
            | ForEach-Object {Update-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -Status Closed -Title $_.Title -Id $_.Name -Severity $_.Severity -OwnerAssignedTo $Owner -OwnerEmail $OwnerEmail -Classification BenignPositive -ClassificationReason SuspiciousButExpected
            }
}

if ($SeverityNum -eq '3'){
    Get-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -ErrorAction Stop
    | where {
        ($_.Status -eq "New" -and 
        $_.CreatedTimeUtc -gt (Get-Date).AddDays(-$Days) -and 
        $_.Severity -eq 'High' -and
        $_.Title -eq $HighTitleList[$HighTitleNum])
        } 
        | ForEach-Object {Update-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -Status Closed -Title $_.Title -Id $_.Name -Severity $_.Severity -OwnerAssignedTo $Owner -OwnerEmail $OwnerEmail -Classification BenignPositive -ClassificationReason SuspiciousButExpected -ClassificationComment $HighComment
        }
}


If ($SeverityNum -eq "X"){
    $HighComment = $(Write-Host 'Enter classification comment for High Severity Incidents: ' -ForegroundColor Yellow -NoNewline; Read-Host)
    Get-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -ErrorAction SilentlyContinue
    | where {
        ($_.Status -eq "New" -and 
        $_.CreatedTimeUtc -gt (Get-Date).AddDays(-$Days) -and 
        $_.Severity -ne 'High')
        } 
        | ForEach-Object {Update-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -Status Closed -Title $_.Title -Id $_.Name -Severity $_.Severity -OwnerAssignedTo $Owner -OwnerEmail $OwnerEmail -Classification BenignPositive -ClassificationReason SuspiciousButExpected
        }
    Get-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -ErrorAction Stop
    | where {
        ($_.Status -eq "New" -and 
        $_.CreatedTimeUtc -gt (Get-Date).AddDays(-$Days) -and 
        $_.Severity -eq 'High')
        } 
        | ForEach-Object {Update-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -Status Closed -Title $_.Title -Id $_.Name -Severity $_.Severity -OwnerAssignedTo $Owner -OwnerEmail $OwnerEmail -Classification BenignPositive -ClassificationReason SuspiciousButExpected -ClassificationComment $HighComment
        }
} 


If ($Severity -eq "All except High"){
    Get-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -ErrorAction Stop
    | where {
            ($_.Status -eq "New" -and 
            $_.CreatedTimeUtc -gt (Get-Date).AddDays(-$Days) -and 
            $_.Severity -ne 'High')
            } 
            | ForEach-Object {Update-AzSentinelIncident -ResourceGroupName $RGList[$RGNum] -WorkspaceName $ResList[$WSNum] -Status Closed -Title $_.Title -Id $_.Name -Severity $_.Severity -OwnerAssignedTo $Owner -OwnerEmail $OwnerEmail -Classification BenignPositive -ClassificationReason SuspiciousButExpected
            }
}

Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "Disconnecting from Azure Account..."
Disconnect-AzAccount
