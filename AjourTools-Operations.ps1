param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('init-system', 'ensure-projection-schemas', 'migrate-schema', 'build-userorganizations', 'build-projections')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$ToolExePath,

    [Parameter(Mandatory = $true)]
    [string]$SystemId,

    [Parameter(Mandatory = $true)]
    [string]$SourceSettingsPath,

    [string]$ArchivePath,
    [string]$DataSource,
    [string]$InitialCatalog,
    [string]$ReadModelDataSource,
    [string]$ReadModelInitialCatalog,
    [string]$SqlUser,
    [string]$SqlPassword,
    [string[]]$ProjectionTypes # <-- Add this for build-projections
)

function Set-DbEnvVars {
    param(
        $DataSource, $InitialCatalog, $ReadModelDataSource, $ReadModelInitialCatalog, $SqlUser, $SqlPassword
    )
    $env:AjourWeb__Connections__MsSql__DataSource = $DataSource
    $env:AjourWeb__Connections__MsSql__InitialCatalog = $InitialCatalog
    $env:AjourWeb__Connections__MsSql__UserID = $SqlUser
    $env:AjourWeb__Connections__MsSql__Password = $SqlPassword

    $env:AjourWeb__Connections__ReadModelDatabase__DataSource = $ReadModelDataSource
    $env:AjourWeb__Connections__ReadModelDatabase__InitialCatalog = $ReadModelInitialCatalog
    $env:AjourWeb__Connections__ReadModelDatabase__UserID = $SqlUser
    $env:AjourWeb__Connections__ReadModelDatabase__Password = $SqlPassword

    $env:AJOUR_TOOLS_CONFIG_BASE_PATH = $SourceSettingsPath
}

switch ($Action) {
    'init-system' {
        if (-not $ArchivePath) {
            Write-Error "ArchivePath is required for init-system."
            exit 1
        }
        Set-DbEnvVars $DataSource $InitialCatalog $ReadModelDataSource $ReadModelInitialCatalog $SqlUser $SqlPassword
        if (-not (Test-Path $ArchivePath)) {
            Write-Host "Archive path does not exist. Creating: $ArchivePath"
            New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null
        }
        Write-Host "Running: $ToolExePath init-system -archivepath $ArchivePath -systemid $SystemId"
        & $ToolExePath init-system -archivepath $ArchivePath -systemid $SystemId
    }
    'ensure-projection-schemas' {
        Set-DbEnvVars $DataSource $InitialCatalog $ReadModelDataSource $ReadModelInitialCatalog $SqlUser $SqlPassword
        Write-Host "Running: $ToolExePath ensure-projection-schemas"
        & $ToolExePath ensure-projection-schemas
    }
    'migrate-schema' {
        Set-DbEnvVars $DataSource $InitialCatalog $ReadModelDataSource $ReadModelInitialCatalog $SqlUser $SqlPassword
        Write-Host "Running: $ToolExePath migrate-schema"
        & $ToolExePath migrate-schema
    }
    'build-userorganizations' {
        Set-DbEnvVars $DataSource $InitialCatalog $ReadModelDataSource $ReadModelInitialCatalog $SqlUser $SqlPassword
        Write-Host "Running: $ToolExePath build-projections -userorganizations"
        & $ToolExePath build-projections -userorganizations
    }
    'build-projections' {
        Set-DbEnvVars $DataSource $InitialCatalog $ReadModelDataSource $ReadModelInitialCatalog $SqlUser $SqlPassword
        $args = @('build-projections')
        if ($ProjectionTypes) {
            $args += $ProjectionTypes
        }
        Write-Host "Running: $ToolExePath $($args -join ' ')"
        & $ToolExePath @args
    }
    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}