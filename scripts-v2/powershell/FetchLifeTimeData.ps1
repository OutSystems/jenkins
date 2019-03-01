Function Invoke-DeploymentAPI ($Method, $Endpoint, $Body)
{
	$Url = "https://$env:LifeTimeUrl/LifeTimeAPI/rest/v2/$Endpoint"
	$ContentType = "application/json"
	$Headers = @{
		Authorization = "Bearer $env:AuthorizationToken"
		Accept = "application/json"
	}

	try { Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers -ContentType $ContentType -Body $body }
	catch { Write-Host $_; exit 9 }
}

Function Export-Json ($InputObject, $Path)
{
   $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
   $Json = ConvertTo-Json $InputObject -Depth 6
   [IO.File]::WriteAllLines($Path, $Json, $Utf8NoBomEncoding)
}

# Fetch latest OS Environments data

$Environments = Invoke-DeploymentAPI -Method GET -Endpoint environments 

$Envs = @{}
foreach ($Environment in $Environments) { $Envs[$Environment.key] = $Environment.name }
Export-Json -InputObject $Envs -Path "environments.json"


$EnvDeploymentZones = @{}
foreach ($Environment in $Environments) {

    $DeploymentZones = Invoke-DeploymentAPI -Method GET -Endpoint "environments/$($Environment.Key)/deploymentzones/"
    $DZs = @{}
    foreach ($DeploymentZone in $DeploymentZones) { $DZs[$DeploymentZone.key] = $DeploymentZone.name }

    $EnvDeploymentZones[$Environment.Key] = @{
        'order'=$Environment.Order;
        'deployment_zones' = $DZs
    }
}
Export-Json -InputObject $EnvDeploymentZones -Path "environment_deployment_zones.json"


$Applications = Invoke-DeploymentAPI -Method GET -Endpoint applications

$Apps = @{}
foreach ($Application in $Applications) { $Apps[$Application.key] = $Application.name }
Export-Json -InputObject $Apps -Path "applications.json"


Write-Output "OS Applications data retrieved successfully."