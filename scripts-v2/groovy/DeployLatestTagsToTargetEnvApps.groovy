import java.net.URL
import groovy.json.JsonSlurper

try {
    def slurper = new JsonSlurper()
    def applications = slurper.parse(new URL("http://<host>:<port>/job/OutSystems/job/FetchLifeTimeData/lastSuccessfulBuild/artifact/applications.json"))
    return applications.values().collect { it }
} catch (Exception e) {
    return []
}