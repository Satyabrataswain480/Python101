param(
    [Parameter(Mandatory = $true)] [string]$ExtractedAppSettingsPath,
    [Parameter(Mandatory = $true)] [string]$GeneratedAppSettingsPath
)
        
# Check if both files exist
if (!(Test-Path $extractedAppSettingsPath)) {
    Write-Error "Extracted appsettings.json file not found at $extractedAppSettingsPath"
    exit 1
}
if (!(Test-Path $generatedAppSettingsPath)) {
    Write-Error "Generated appsettings.json file not found at $generatedAppSettingsPath"
    exit 1
}

# Load both JSON files
$extractedAppSettings = Get-Content $extractedAppSettingsPath | ConvertFrom-Json
$generatedAppSettings = Get-Content $generatedAppSettingsPath | ConvertFrom-Json

# Array to store missing keys
$missingKeys = @()

# Function to recursively compare keys
function Compare-JsonKeys {
    param (
        [Parameter(Mandatory = $true)] $ReferenceObject,
        [Parameter(Mandatory = $true)] $DifferenceObject,
        [Parameter(Mandatory = $true)] $ParentPath
    )

    foreach ($key in $ReferenceObject.PSObject.Properties.Name) {
        $currentPath = if ($ParentPath) { "$ParentPath.$key" } else { $key }

        # Check if the key exists in the DifferenceObject
        if (-not $DifferenceObject.PSObject.Properties[$key]) {
            # Add missing key to the array
            $script:missingKeys += $currentPath
            continue
        }

        # If the value is an object, recurse into it
        if ($ReferenceObject.$key -is [PSCustomObject] -and $DifferenceObject.$key -is [PSCustomObject]) {
            Compare-JsonKeys -ReferenceObject $ReferenceObject.$key `
                                -DifferenceObject $DifferenceObject.$key `
                                -ParentPath $currentPath
        } elseif ($ReferenceObject.$key -is [PSCustomObject] -and -not ($DifferenceObject.$key -is [PSCustomObject])) {
            # If the key exists but is not an object in the generated file, treat it as missing
            $script:missingKeys += $currentPath
        }
    }
}

# Start the recursive comparison
Compare-JsonKeys -ReferenceObject $extractedAppSettings `
                    -DifferenceObject $generatedAppSettings `
                    -ParentPath ""

# Check if there are any missing keys
if ($missingKeys.Count -gt 0) {
    Write-Error "Validation failed. Missing keys: $($missingKeys -join ', ')"
    exit 1
} else {
    Write-Host "Validation passed. All required keys from the extracted appsettings.json are present in the generated appsettings.json."
}