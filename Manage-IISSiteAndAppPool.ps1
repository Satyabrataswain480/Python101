param(
    [Parameter(Mandatory = $true)]
    [string]$AppPoolName,
    [Parameter(Mandatory = $true)]
    [ValidateSet('start', 'stop')]
    [string]$Action
)

Import-Module WebAdministration

# Start/Stop IIS Site
if (Get-Website -Name $AppPoolName) {
    $siteState = (Get-Website -Name $AppPoolName).State
    if ($Action -eq 'start') {
        if ($siteState -ne "Started") {
            Start-Website -Name $AppPoolName
            Write-Host "Started IIS site '$AppPoolName'."
        } else {
            Write-Host "IIS site '$AppPoolName' is already started."
        }
    } elseif ($Action -eq 'stop') {
        if ($siteState -ne "Stopped") {
            Stop-Website -Name $AppPoolName
            Write-Host "Stopped IIS site '$AppPoolName'."
        } else {
            Write-Host "IIS site '$AppPoolName' is already stopped."
        }
    }
} else {
    Write-Host "IIS site '$AppPoolName' does not exist."
}

# Start/Stop IIS App Pool
if (Test-Path "IIS:\AppPools\$AppPoolName") {
    $poolState = (Get-WebAppPoolState -Name $AppPoolName).Value
    if ($Action -eq 'start') {
        if ($poolState -ne "Started") {
            Start-WebAppPool -Name $AppPoolName
            Write-Host "Started application pool '$AppPoolName'."
        } else {
            Write-Host "Application pool '$AppPoolName' is already started."
        }
    } elseif ($Action -eq 'stop') {
        if ($poolState -ne "Stopped") {
            Stop-WebAppPool -Name $AppPoolName
            Write-Host "Stopped application pool '$AppPoolName'."
        } else {
            Write-Host "Application pool '$AppPoolName' is already stopped."
        }
    }
} else {
    Write-Host "IIS app pool '$AppPoolName' does not exist."
}