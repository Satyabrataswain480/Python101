function Get-ServerCredentials {
    param(
        [Parameter(Mandatory=$true)][string]$Environment,
        [Parameter(Mandatory=$true)][string]$Customer,
        [Parameter(Mandatory=$true)][ValidateSet('web','sql','file')]$ServerType,
        [Parameter(Mandatory=$true)][string]$GenericJsonPath,
        [Parameter(Mandatory=$true)][string]$VarsJsonPath,
        [Parameter(Mandatory=$true)][string]$ServerSecretsPath,
        [Parameter(Mandatory=$true)][string]$KeyVaultName
    )

    # Load configs
    $genericConfig = Get-Content $GenericJsonPath | ConvertFrom-Json
    $varsConfig = Get-Content $VarsJsonPath | ConvertFrom-Json
    $serverSecrets = Get-Content $ServerSecretsPath | ConvertFrom-Json

    # Get customer config
    $customerObj = $genericConfig.PSObject.Properties | Where-Object { $_.Name -eq $Customer }
    if (-not $customerObj) {
        throw "Customer '$Customer' not found in $GenericJsonPath"
    }
    $customerConfig = $customerObj.Value

    # Determine server IP based on type
    if ($ServerType -eq 'web') {
        $serverIp = $customerConfig.ServerIP
    } elseif ($ServerType -eq 'sql') {
        $serverIp = $varsConfig.DbHost
    } elseif ($ServerType -eq 'file') {
        $fileShareName = $customerConfig.FileShare
        $serverIp = $varsConfig.fileShare.$fileShareName.ipAddress -replace "^\\\\", ""
    }

    # Find server config in serverSecrets.json
    $envSecrets = $serverSecrets.$Environment
    $serverConfigs = $envSecrets.PSObject.Properties | ForEach-Object { $_.Value }
    $serverConfig = $serverConfigs | Where-Object { $_.ip -eq $serverIp }
    if (-not $serverConfig) {
        throw "Server configuration for IP '$serverIp' not found in $Environment environment in $ServerSecretsPath"
    }

    # Get secret keys
    $svcNameKey = $serverConfig.svcName
    $svcPassKey = $serverConfig.svcPass

    # Fetch secrets from Key Vault
    $svcName = az keyvault secret show --vault-name $KeyVaultName --name $svcNameKey --query value -o tsv
    $svcPass = az keyvault secret show --vault-name $KeyVaultName --name $svcPassKey --query value -o tsv

    if ($ServerType -eq 'sql') {
        $sqlNameKey = $serverConfig.sqlName
        $sqlPassKey = $serverConfig.sqlPass

        if ($sqlNameKey -and $sqlPassKey) {
            $sqlName = az keyvault secret show --vault-name $KeyVaultName --name $sqlNameKey --query value -o tsv
            $sqlPass = az keyvault secret show --vault-name $KeyVaultName --name $sqlPassKey --query value -o tsv
        }

        return @{
            SvcName = $svcName
            SvcPass = $svcPass
            SqlName = $sqlName
            SqlPass = $sqlPass
            ServerIP = $serverIp
        }
    } 
    else {
        return @{
            SvcName = $svcName
            SvcPass = $svcPass
            ServerIP = $serverIp
        }
    }
}