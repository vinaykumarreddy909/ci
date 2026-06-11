import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.*
import org.jenkinsci.plugins.workflow.cps.*
import hudson.plugins.git.*

def jenkins = Jenkins.instanceOrNull
if (jenkins == null) return

def jobName = 'flutter-mfe'

// No credentials needed if ci repo is public.
// Change null to 'github-credentials' if the repo is private.
def scm = new GitSCM(
    [new UserRemoteConfig(
        'https://github.com/vinaykumarreddy909/ci.git',
        null, null, null
    )],
    [new BranchSpec('*/main')],
    false, [], null, null, []
)

def definition = new CpsScmFlowDefinition(scm, 'Jenkinsfile')
definition.setLightweight(false)

def existing = jenkins.getItem(jobName)
if (existing != null) {
    existing.setDefinition(definition)
    existing.save()
    println "[init] Updated definition for existing pipeline '${jobName}'"
} else {
    def job = jenkins.createProject(WorkflowJob, jobName)
    job.setDefinition(definition)
    job.save()
    println "[init] Created pipeline job '${jobName}' pointing at ci.git"
}
