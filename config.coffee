
# Config — defaults can be overridden with environment vars
env = require 'node-env-file'

# Load in environment variables from the .env file within the repo.
# This file is NOT commited to the repository, so will need to be manually created.
env('./.env');

config =
    collections: ['customers', 'people']
    port: process.env.APP_PORT
    # if true, a server will listen on port 80 and redirect to HTTPS
    redirect80: true

    jira_user: process.env.JIRA_USER
    jira_password: process.env.JIRA_PASSWORD

    gitlab_url: 'https://gitlab.hq.jadu.net/'
    gitlab_token: process.env.GITLAB_TOKEN

    toran_proxy_package_url: 'https://toran-proxy.hq.jadu.net/repo/private/p/#{package_name}.json'

    mongo_url: 'mongodb://localhost/crater'

    releases_url: 'http://localhost:3002'

    google_client_id: process.env.GOOGLE_CLIENT_ID
    google_client_email: process.env.GOOGLE_CLIENT_EMAIL
    google_private_key: process.env.GOOGLE_PRIVATE_KEY

    sshUser: 'root'
    sshPrivateKeyPath: process.env.DEV_SSH_KEY

    crater_key: process.env.CRATER_KEY
    crater_cert: process.env.CRATER_CERT
    chain: process.env.CHAIN

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
