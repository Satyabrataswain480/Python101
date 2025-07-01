param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('ToWebServer', 'ToFileServer')]
    [string]$Direction,
    [Parameter(Mandatory = $true)]
    [string]$WebServerIP,
    [Parameter(Mandatory = $true)]
    [string]$WebSvcName,
    [Parameter(Mandatory = $true)]
    [string]$WebSvcPass,
    [Parameter(Mandatory = $true)]
    [string]$FileServerIP,
    [Parameter(Mandatory = $true)]
    [string]$FileSvcName,
    [Parameter(Mandatory = $true)]
    [string]$FileSvcPass,
    [Parameter(Mandatory = $true)]
    [string]$SystemId,
    [Parameter(Mandatory = $true)]
    [string]$RunnerTemp
)

$ErrorActionPreference = "Stop"

function Copy-Projections {
    param(
        [string]$SourceIP, [string]$SourceUser, [string]$SourcePass, [string]$SourcePath,
        [string]$DestIP, [string]$DestUser, [string]$DestPass, [string]$DestPath,
        [string]$RunnerTemp
    )

    # Step 1: Copy from source server to runner
    $session = & .\.github\scripts\Create-PSSession.ps1 -ComputerName $SourceIP -Username $SourceUser -Password $SourcePass
    if (-not (Test-Path $RunnerTemp)) {
        New-Item -ItemType Directory -Path $RunnerTemp -Force
    }
    $fileCount = Invoke-Command -Session $session -ScriptBlock {
        param($path)
        (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue).Count
    } -ArgumentList $SourcePath

    if ($fileCount -eq 0) {
        Write-Host "WARNING: Source folder is empty: $SourcePath"
        Remove-PSSession -Session $session
        return
    } else {
        Write-Host "Copying $fileCount files from $SourceIP:$SourcePath to runner at $RunnerTemp..."
        Copy-Item -FromSession $session -Path "$SourcePath\*" -Destination $RunnerTemp -Recurse -Force
        Remove-PSSession -Session $session
    }

    # Step 2: Copy from runner to destination server
    $session = & .\.github\scripts\Create-PSSession.ps1 -ComputerName $DestIP -Username $DestUser -Password $DestPass
    Invoke-Command -Session $session -ScriptBlock {
        param($destPath)
        if (-not (Test-Path $destPath)) {
            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
        }
    } -ArgumentList $DestPath

    Write-Host "Copying files from runner to $DestIP:$DestPath..."
    Copy-Item -Path "$RunnerTemp\*" -Destination $DestPath -ToSession $session -Recurse -Force
    Remove-PSSession -Session $session
}

$dfsPath = "E:\$SystemId-projections"
$webPath = $env:TARGET_WORKSPACE_PATH

if ($Direction -eq 'ToWebServer') {
    Copy-Projections -SourceIP $FileServerIP -SourceUser $FileSvcName -SourcePass $FileSvcPass -SourcePath $dfsPath `
                     -DestIP $WebServerIP -DestUser $WebSvcName -DestPass $WebSvcPass -DestPath $webPath `
                     -RunnerTemp $RunnerTemp
} elseif ($Direction -eq 'ToFileServer') {
    Copy-Projections -SourceIP $WebServerIP -SourceUser $WebSvcName -SourcePass $WebSvcPass -SourcePath $webPath `
                     -DestIP $FileServerIP -DestUser $FileSvcName -DestPass $FileSvcPass -DestPath $dfsPath `
                     -RunnerTemp $RunnerTemp
}