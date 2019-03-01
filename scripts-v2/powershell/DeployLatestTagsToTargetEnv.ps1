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

Function Import-Json ($Path)
{
   $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
   ConvertFrom-Json ([IO.File]::ReadAllText($Path, $Utf8NoBomEncoding))
}

Function Get-DeploymentZoneKey ($Mapping, $EnvKey, $AppKey)
{
    if ($Mapping.$AppKey.$EnvKey -eq $null) { "" } else { $Mapping.$AppKey.$EnvKey }
}

Function Get-KeyByName ($Mapping, $Name) {
    ($Mapping.psobject.Properties | where Value -eq $Name).Name
}

# Translate environment names to the corresponding keys
$EnvKeyToName = Import-Json "$env:WORKSPACE\environments.json"

$SourceEnvKey = Get-KeyByName $EnvKeyToName $env:SourceEnvironment
$TargetEnvKey = Get-KeyByName $EnvKeyToName $env:TargetEnvironment

$AppKeyToName = Import-Json "$env:WORKSPACE\applications.json"

# Translate application names to the corresponding keys
$AppKeys = ( $env:ApplicationsToDeploy -split "," | % { Get-KeyByName $AppKeyToName $_ } )
echo "Creating deployment plan from '$env:SourceEnvironment' ($SourceEnvKey) to '$env:TargetEnvironment' ($TargetEnvKey) including applications: $env:ApplicationsToDeploy ($($AppKeys -join ','))."

# Get latest version Tags for each OS Application to deploy
$AppVersionKeys = @( $AppKeys | %{ Invoke-DeploymentAPI -Method GET -Endpoint "applications/$_/versions?MaximumVersionsToReturn=1" } | %{ $_.Key } )

# Get the deployment zone for each OS Application to deploy
$AppDeploymentZones = if (Test-Path "$env:WORKSPACE\app_deployment_zones.json") { Import-Json "$env:WORKSPACE\app_deployment_zones.json" } else { @{} }
$AppDeploymentZoneKeys = @( $AppKeys | %{ Get-DeploymentZoneKey $AppDeploymentZones $TargetEnvKey $_ } )

# Create a new LifeTime Deployment Plan that includes the retrieved version Tags and configured Deployment Zones
$ApplicationOperations = @()
for ($i = 0; $i -lt $AppDeploymentZoneKeys.Length; $i++) {
    $ApplicationOperations += 
@"
    {
        "ApplicationVersionKey": "$($AppVersionKeys[$i])",
        "DeploymentZoneKey": "$($AppDeploymentZoneKeys[$i])"
    }
"@
}

$RequestBody = @"
{
	"ApplicationOperations": [$($ApplicationOperations -join ',')],
	"Notes" : "Automatic deployment plan created by Jenkins",
	"SourceEnvironmentKey":"$SourceEnvKey",
	"TargetEnvironmentKey":"$TargetEnvKey"
}
"@

$DeploymentPlanKey = Invoke-DeploymentAPI -Method POST -Endpoint "deployments" -Body $RequestBody
echo "Deployment plan '$DeploymentPlanKey' created successfully."

# Start Deployment Plan execution
$DeploymentPlanStart = Invoke-DeploymentAPI -Method POST -Endpoint "deployments/$DeploymentPlanKey/start"
echo "Deployment plan '$DeploymentPlanKey' started being executed."

# Sleep thread until deployment has finished
$WaitCounter = 0
do {
	Start-Sleep -s $env:SleepPeriodInSecs
	$WaitCounter += $env:SleepPeriodInSecs
	echo "$WaitCounter secs have passed since the deployment started..."	
	
	# Check Deployment Plan status. If deployment is still running then go back to step 5
	$DeploymentStatus =  Invoke-DeploymentAPI -Method GET -Endpoint "deployments/$DeploymentPlanKey/status" | %{ $_.DeploymentStatus }
	
	if ($DeploymentStatus -ne "running") {	
		# Return Deployment Plan status
		echo "Deployment plan finished with status '$DeploymentStatus'."
		exit 0
	}
}
while ($WaitCounter -lt $env:DeploymentTimeoutInSecs)

# Deployment timeout reached. Exit script with error  
echo "Timeout occurred while deployment plan is still in 'running' status."
exit 1