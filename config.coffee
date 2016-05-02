
# Config — defaults can be overridden with environment vars

config =
    jira_protocol: 'https'
    jira_host: 'jadultd.atlassian.net'
    jira_port: '443'
    jira_user: process.env.JIRA_USER
    jira_password: process.env.JIRA_PASSWORD
    jira_issueUrl: 'https://jadultd.atlassian.net/browse/#{key}'

    jira_status_inProgress: ['In Progress', 'WebDev in Progress', 'UX in Progress']
    jira_status_toTest: 'Testing ToDo: Spacecraft'
    jira_status_webdevToDo: 'WebDev ToDo'
    jira_status_uxToDo: 'UX ToDo'
    jira_status_awaitingReview: ['Code Review ToDo']
    jira_status_awaitingMerge: ['Awaiting Merge', 'Awaiting Merge: Spacecraft']
    jira_status_readyToRelease: 'Ready for Release: Spacecraft'

    # Custom field names
    jira_field_reportingCustomer: 'customfield_10025'
    jira_field_server: 'customfield_12302'
    jira_field_deployment_version: 'customfield_11803'
    jira_field_release_version: 'customfield_12201'
    jira_field_story_points: 'customfield_10004'

    gitlab_url: 'https://gitlab.hq.jadu.net/'
    gitlab_token: process.env.GITLAB_TOKEN

    toran_proxy_package_url: 'https://toran-proxy.hq.jadu.net/repo/private/p/#{package_name}.json'

    mongo_url: 'mongodb://localhost/customers'

    google_client_id: process.env.GOOGLE_CLIENT_ID
    google_client_email: process.env.GOOGLE_CLIENT_EMAIL
    google_private_key: process.env.GOOGLE_PRIVATE_KEY

    sshUser: 'root'
    sshPrivateKeyPath: '/root/.ssh/jadu_webdev_key'

    timezone: 'Europe/London'

    # passed to inflect.inflections
    inflections:
        # specify singular words for the given aliases
        singular:
            'alias': 'alias'
            'aliases': 'alias'

# Show a message if secrets haven't been set in the environment
(require './src/utils/assert_config_secrets') config

# Mix in dev config
if '--debug' in process.argv
    devConfig = require './config-dev'
    config[key] = value for own key, value of devConfig

module.exports = config
