import java.net.URL
import org.boon.Boon
import groovy.json.JsonSlurper

def host = "localhost"
def port = 8080

def slurper = new JsonSlurper()

def applications = slurper.parse(new URL("http://${host}:${port}/job/OutSystems/job/FetchLifeTimeData/lastSuccessfulBuild/artifact/applications.json"))

def environments = slurper.parse(new URL("http://${host}:${port}/job/OutSystems/job/FetchLifeTimeData/lastSuccessfulBuild/artifact/environments.json"))

def environmentDeploymentZones = slurper.parse(new URL("http://${host}:${port}/job/OutSystems/job/FetchLifeTimeData/lastSuccessfulBuild/artifact/environment_deployment_zones.json"))

def applicationDeploymentZones;
try {
    applicationDeploymentZones = slurper.parse(new URL("http://${host}:${port}/job/OutSystems/job/SetApplicationDeploymentZones/lastSuccessfulBuild/artifact/app_deployment_zones.json"))
} catch (Exception e) {
    applicationDeploymentZones  = [:]
}

// Add special 'keep existing' zone to each environment
environmentDeploymentZones.values().each { env ->
    env.deployment_zones[""] = "* Keep Existing *"
}

def environmentName = { envKey ->
    environments[envKey]
}

def applicationDeploymentZoneForEnvironment = { appKey, envKey ->
    if (!applicationDeploymentZones[appKey]) {
        return ""
    }
    if (!applicationDeploymentZones[appKey][envKey]) {
        return ""
    }
    return applicationDeploymentZones[appKey][envKey]
}

def alphaName = { name ->
    name
            .replaceAll("[^\\p{Alpha}|\\p{Space}]", "")
            .replaceAll("\\p{Space}", "_")
}

def deploymentZonesUIFragment = environmentDeploymentZones
        .entrySet()
        .toSorted { env1, env2 -> env1.value.order <=> env2.value.order }
        .withIndex()
        .collect { env, i ->
    def envName =  alphaName(environmentName(env.key))
    def deploymentZones = env.value.deployment_zones.entrySet()
    def deploymentZonesKeys = deploymentZones.collect { /"${it.key}"/ }.join ', '
    def deploymentZonesNames = deploymentZones.collect { /"${it.value}"/ }.join ', '
    """
                    "${envName}_env" : {
                        "type" : "string",
                        "enum" : [ ${deploymentZonesKeys} ],
                        "default" : "",
                        "options" : {
                            "enum_titles": [ ${deploymentZonesNames} ]
                        },
                        "propertyOrder" : "${i * 2 + 2}"
                    },
                    "${envName}_env_key" : {
                        "type" : "string",
                        "default" : "${env.key}",
                        "propertyOrder" : "${i * 2 + 3}",
                        "options" : {
                            "hidden" : true
                        }
                    }
                """
}
        .join ','

def initialValues = applications
        .entrySet()
        .toSorted { a1, a2 -> a1.value  <=> a2.value }
        .collect { a ->
    /{"application":"${a.value}", "application_key":"${a.key}", / +
            environmentDeploymentZones
                    .entrySet()
                    .toSorted { e1, e2 -> e1.value.order <=> e2.value.order }
                    .collect { e ->
                def envName = alphaName(environmentName(e.key))
                def envDeploymentZone = applicationDeploymentZoneForEnvironment(a.key, e.key)
                "\"${envName}_env\":\"${envDeploymentZone}\""
            }
            .join(',') + "}"
}
.join(',')

def jsonEditorOptions = Boon.fromJson(/{
        "disable_edit_json": true,
        "disable_properties": true,
        "no_additional_properties": true,
        "disable_collapse": true,
        "disable_array_add": true,
        "disable_array_delete": true,
        "disable_array_reorder": true,
        "theme": "bootstrap2",
        "iconlib":"fontawesome4",
        "schema": {
            "type": "array",
            "format": "table",
            "title": " ",
            "uniqueItems": "true",
            "items": {
                "type": "object",
                "properties": {
                    "application": {
                        "type": "string",
                        "readOnly": true,
                        "propertyOrder" : 1
                    },
                    "application_key" : {
                        "type" : "string",
                        "readOnly" : true,
                        "propertyOrder" : 2,
                        "options" : {
                            "hidden" : true
                        }
                    },
                    ${deploymentZonesUIFragment}
                }
            }
        },
        "startval" : [${initialValues}]
}/)

return jsonEditorOptions