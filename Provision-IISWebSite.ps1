param(
    [Parameter(Mandatory = $true)] [string]$ServiceName,
    [Parameter(Mandatory = $true)] [string]$ReleasePath,
    [Parameter(Mandatory = $true)] [string]$PublishWebPath,
    [Parameter(Mandatory = $true)] [string]$DeployVersion,
    [Parameter(Mandatory = $true)] [string]$SystemId,
    [Parameter(Mandatory = $true)] [string]$Environment,
    [Parameter(Mandatory = $true)] [string]$Slug
)

Import-Module WebAdministration
$sourceSettingsPath = "E:\Customers\{0}"

$targetPath = Join-Path $ReleasePath "$DeployVersion\web"

# Check if source path exists; if not, exit workflow
if (!(Test-Path $PublishWebPath)) {
    Write-Host "Source path '$PublishWebPath' does not exist. Exiting workflow."
    exit 1
}

# Check if target directory exists
if (Test-Path $targetPath) {
    Write-Host "Directory '$targetPath' already exists. Skipping copy of contents."
} else {
    Write-Host "Target directory '$targetPath' does not exist. Creating..."
    New-Item -ItemType Directory -Path $targetPath | Out-Null

    Write-Host "Copying contents from '$PublishWebPath' to '$targetPath'..."
    Copy-Item -Path (Join-Path $PublishWebPath '*') -Destination $targetPath -Recurse -Force -Exclude 'appsettings.json'
    Write-Host "Copy completed."
}

# Check if app pool exists using Get-WebAppPoolState
if (Test-Path "IIS:\AppPools\$ServiceName") {
    Write-Host "Application pool '$ServiceName' already exists."
} else {
    Write-Host "Creating application pool '$ServiceName'."
    try {
        New-WebAppPool -Name $ServiceName -Force
    } catch {
        Write-Host "Failed to create application pool '$ServiceName'. Error: $($Error[0].Message)"
    }
}

# Set application pool identity to ApplicationPoolIdentity using appcmd
Write-Host "Checking application pool identity..."
$identityType = & $env:windir\system32\inetsrv\appcmd.exe list AppPool "$ServiceName" /text:processModel.identityType
if ($identityType -ne "ApplicationPoolIdentity") {
    Write-Host "Setting application pool identity to ApplicationPoolIdentity."
    & $env:windir\system32\inetsrv\appcmd.exe set AppPool "$ServiceName" /processModel.identityType:ApplicationPoolIdentity
} else {
    Write-Host "Application pool identity is already set to ApplicationPoolIdentity."
}

# Set .NET framework version: No Managed Code
Write-Host "Checking .NET framework version..."
$runtimeVersion = & $env:windir\system32\inetsrv\appcmd.exe list AppPool "$ServiceName" /text:managedRuntimeVersion
if ($runtimeVersion -ne "") {
    Write-Host "Setting .NET framework version to No Managed Code."
    & $env:windir\system32\inetsrv\appcmd.exe set AppPool "$ServiceName" /managedRuntimeVersion:""
} else {
    Write-Host ".NET framework version is already set to No Managed Code."
}

# Create website if not exists, else update physical path
if (Get-Website -Name $ServiceName ) {
    Write-Host "Site '$ServiceName' already exists. Updating physical path to '$targetPath'."
    Set-ItemProperty "IIS:\Sites\$ServiceName" -Name physicalPath -Value $targetPath
} else {
    Write-Host "Creating website '$ServiceName'."
    New-Website -Name $ServiceName -PhysicalPath $targetPath -ApplicationPool $ServiceName
    Start-Sleep -Seconds 5  # Wait for IIS to commit changes
}

# Configure authentication only if site exists
if (Get-Website -Name $ServiceName) {
    try {
        # Enable Anonymous authentication
        $anonymousAuth = Get-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name enabled -Location $ServiceName
        if ($anonymousAuth.Value -ne $true) {
            Write-Host "Enabling Anonymous authentication."
            Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name enabled -Value $true -Location $ServiceName
        } else {
            Write-Host "Anonymous authentication is already enabled."
        }

        # Disable Basic authentication
        $basicAuth = Get-WebConfigurationProperty -Filter "/system.webServer/security/authentication/basicAuthentication" -Name enabled -Location $ServiceName
        if ($basicAuth.Value -ne $false) {
            Write-Host "Disabling Basic authentication."
            Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/basicAuthentication" -Name enabled -Value $false -Location $ServiceName
        } else {
            Write-Host "Basic authentication is already disabled."
        }

        # Disable Windows authentication
        $windowsAuth = Get-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name enabled -Location $ServiceName
        if ($windowsAuth.Value -ne $false) {
            Write-Host "Disabling Windows authentication."
            Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name enabled -Value $false -Location $ServiceName
        } else {
            Write-Host "Windows authentication is already disabled."
        }
    } catch {
        Write-Host "Error configuring IIS authentication: $_"
    }
} else {
    Write-Host "Site '$ServiceName' does not exist; skipping authentication configuration."
}

Write-Host "Configuring IIS bindings based on environment..."

$site = Get-Website -Name $ServiceName
$existingBindings = $site.Bindings.Collection

# Remove default binding with empty Host Name if it exists
foreach ($b in $existingBindings) {
    if ($b.protocol -eq 'http' -and $b.bindingInformation -eq "*:80:") {
        Write-Host "Removing default catch-all binding '*:80:'."
        Remove-WebBinding -Name $ServiceName -Protocol http -Port 80 -IPAddress "*" -HostHeader ""
    }
}

if ($Environment -eq 'test') {
    $desiredBindings = @(
        "ajour-$SystemId.ajoursystem.tech:80",
        "$Slug.ajoursystem.tech:80"
    )
} elseif ($Environment -eq 'production') {
    $desiredBindings = @(
        "ajour-$SystemId.ajoursystem.net:80",
        "$Slug.ajoursystem.net:80"
    )
} else {
    Write-Host "Unknown environment '$Environment'. No bindings will be configured."
    $desiredBindings = @()
}

function BindingExists($hostname, $port, $bindingsCollection) {
    $ip = "*"
    $bindingInfoToCheck = "$ip`:$port`:$hostname"
    foreach ($b in $bindingsCollection) {
        if ($b.bindingInformation -eq $bindingInfoToCheck -and $b.protocol -eq 'http') {
            return $true
        }
    }
    return $false
}

foreach ($bindingInfo in $desiredBindings) {
    $parts = $bindingInfo -split ':'
    if ($parts.Length -ne 2) {
        throw "Invalid binding format: $bindingInfo"
    }
    $hostname = $parts[0]
    $port = [int]$parts[1]

    if (BindingExists $hostname $port $existingBindings) {
        Write-Host "Binding '$bindingInfo' already exists. Skipping."
    } else {
        Write-Host "Binding '$bindingInfo' does not exist. Creating..."
        try {
            New-WebBinding -Name $ServiceName -Protocol http -IPAddress "*" -Port $port -HostHeader $hostname -ErrorAction Stop
            Write-Host "Binding '$bindingInfo' created successfully."
        } catch {
            Write-Error "Failed to create binding '$bindingInfo'. Error: $_"
            throw  # Rethrow to stop pipeline immediately
        }
    }
}

Write-Host "IIS bindings configuration complete."

# Set IIS site environment variable to load appsettings
function Set-OrUpdateEnvVariable {
    param(
        [string]$siteName,
        [string]$varName,
        [string]$varValue
    )

    $sectionPath = "system.webServer/aspNetCore"
    $envVarFilter = "environmentVariables"

    # Get existing environment variables collection
    $existingVars = Get-WebConfigurationProperty -PSPath "IIS:\Sites\$siteName" -Filter "$sectionPath/$envVarFilter" -Name Collection

    # Try to find existing variable
    $existingVar = $existingVars | Where-Object { $_.name -eq $varName }

    if ($existingVar.value -eq $varValue) {
        Write-Host "Environment variable '$varName' already set to desired value. Skipping."
    }  else {
        Write-Host "Environment variable '$varName' does not exist. Creating..."
        Add-WebConfigurationProperty -PSPath "IIS:\Sites\$siteName" `
            -Filter "$sectionPath/$envVarFilter" `
            -Name Collection `
            -Value @{ name = $varName; value = $varValue }

        Write-Host "Created environment variable '$varName' with value '$varValue'."
    }
}
# Use the function to set/update the variable
$appsettingsFile = Join-Path $sourceSettingsPath 'appsettings.json'
Set-OrUpdateEnvVariable -siteName $ServiceName -varName "AjourWeb_IIS_SITE_CONFIG_PATH_FORMAT" -varValue $appsettingsFile