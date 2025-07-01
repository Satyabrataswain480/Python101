param(
    [Parameter(Mandatory = $true)] [string]$ExtractedSettingsPath,
    [Parameter(Mandatory = $true)] [string]$GeneratedSettingsPath,
    [Parameter(Mandatory = $true)] [string]$ExtractedAppSettingsPath
)

if (!(Test-Path $ExtractedSettingsPath)) {
    Write-Error "Extracted settings.json file not found at $ExtractedSettingsPath"
    exit 1
}
if (!(Test-Path $GeneratedSettingsPath)) {
    Write-Error "Generated settings.json file not found at $GeneratedSettingsPath"
    exit 1
}
if (!(Test-Path $ExtractedAppSettingsPath)) {
    Write-Error "Extracted appsettings.json file not found at $ExtractedAppSettingsPath"
    exit 1
}

$extractedSettings = Get-Content $ExtractedSettingsPath | ConvertFrom-Json
$generatedSettings = Get-Content $GeneratedSettingsPath | ConvertFrom-Json
$extractedAppSettings = Get-Content $ExtractedAppSettingsPath | ConvertFrom-Json

$missingKeys = @()

function Compare-JsonKeys {
    param (
        [Parameter(Mandatory = $true)] $ReferenceObject,
        [Parameter(Mandatory = $true)] $DifferenceObject1,
        [Parameter(Mandatory = $true)] $DifferenceObject2,
        [Parameter(Mandatory = $true)] $ParentPath
    )

    foreach ($key in $ReferenceObject.PSObject.Properties.Name) {
        $currentPath = if ($ParentPath) { "$ParentPath.$key" } else { $key }

        # Check if the key exists in either DifferenceObject1 or DifferenceObject2
        if (-not $DifferenceObject1.PSObject.Properties[$key] -and -not $DifferenceObject2.PSObject.Properties[$key]) {
            # Add missing key to the array
            $script:missingKeys += $currentPath
            continue
        }

        # If the value is an object, recurse into it
        if ($ReferenceObject.$key -is [PSCustomObject]) {
            $diffObj1 = $null
            $diffObj2 = $null

            if ($DifferenceObject1.PSObject.Properties[$key]) {
                $diffObj1 = $DifferenceObject1.$key
            } else {
                $diffObj1 = [PSCustomObject]@{}
            }

            if ($DifferenceObject2.PSObject.Properties[$key]) {
                $diffObj2 = $DifferenceObject2.$key
            } else {
                $diffObj2 = [PSCustomObject]@{}
            }

            Compare-JsonKeys -ReferenceObject $ReferenceObject.$key `
                              -DifferenceObject1 $diffObj1 `
                              -DifferenceObject2 $diffObj2 `
                              -ParentPath $currentPath
        }
    }
}

Compare-JsonKeys -ReferenceObject $extractedSettings `
                  -DifferenceObject1 $extractedAppSettings `
                  -DifferenceObject2 $generatedSettings `
                  -ParentPath ""

if ($missingKeys.Count -gt 0) {
    Write-Error "Validation failed. Missing keys: $($missingKeys -join ', ')"
    exit 1
} else {
    Write-Host "Validation passed. All required keys from settings.json are present in either appsettings.json or generated settings.json."
}