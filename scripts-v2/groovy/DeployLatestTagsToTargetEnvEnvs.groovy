import java.net.URL
import groovy.json.JsonSlurper

try {
    def slurper = new JsonSlurper()
    def environments = slurper.parse(new URL("http://<host>:<port>/job/OutSystems/job/FetchLifeTimeData/lastSuccessfulBuild/artifact/environments.json"))
    return environments.values().collect { it }
} catch (Exception e) {
    return []
}