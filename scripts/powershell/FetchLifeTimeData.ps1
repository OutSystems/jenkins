<###################################################################################>
<#       Script: FetchLifeTimeData                                                 #>
<#  Description: Fetch the latest Application and Environment data in LifeTime     #>
<#               for invoking the Deployment API.                                  #>
<#         Date: 2017-10-05                                                        #>
<#       Author: rrmendes                                                          #>
<#         Path: jenkins/scripts/powershell/FetchLifeTimeData.ps1                  #>
<###################################################################################>

<###################################################################################>
<#     Function: CallDeploymentAPI                                                 #>
<#  Description: Helper function that wraps calls to the LifeTime Deployment API.  #>
<#       Params: -Method: HTTP Method to use for API call                          #>
<#               -Endpoint: Endpoint of the API to invoke                          #>
<#               -Body: Request body to send when calling the API                  #>
<###################################################################################>
function CallDeploymentAPI ($Method, $Endpoint, $Body)
{
	$Url = "https://$env:LifeTimeUrl/LifeTimeAPI/rest/v1/$Endpoint"
	$ContentType = "application/json"
	$Headers = @{
		Authorization = "Bearer $env:AuthorizationToken"
		Accept = "application/json"
	}
		
	try { Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers -ContentType $ContentType -Body $body }
	catch { Write-Host $_; exit 9 }
}

# Fetch latest OS Environments data 
$Environments = CallDeploymentAPI -Method GET -Endpoint environments 
$Environments | Format-Table Name,Key > LT.Environments.mapping
"Environments=" + ( ( $Environments | %{ $_.Name } | Sort-Object ) -join "," ) | Out-File LT.Environments.properties -Encoding Default
echo "OS Environments data retrieved successfully."

# Fetch latest OS Applications data
$Applications = CallDeploymentAPI -Method GET -Endpoint applications 
$Applications | Format-Table Name,Key > LT.Applications.mapping
"Applications=" + ( ( $Applications | %{ $_.Name } | Sort-Object ) -join "," ) | Out-File LT.Applications.properties -Encoding Default
echo "OS Applications data retrieved successfully."