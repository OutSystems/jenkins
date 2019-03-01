Function Export-Json ($InputObject, $Path)
{
   $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
   $Json = ConvertTo-Json $InputObject -Depth 6
   [IO.File]::WriteAllLines($Path, $Json, $Utf8NoBomEncoding)
}

$apps = ConvertFrom-Json ((Get-Item env:application_deployment_zones).Value)

$appZones = @{}
foreach ($app in $apps) {
    $deploymentZones = @{}
    foreach ($dz in ($app.psobject.properties.name | where { $_.EndsWith("_env") })) {
        $deploymentZones[$app.($dz + '_key')] = $app.$dz
    }
    $appZones[$app.application_key] = $deploymentZones
}

Export-Json -InputObject $appZones -Path "app_deployment_zones.json"