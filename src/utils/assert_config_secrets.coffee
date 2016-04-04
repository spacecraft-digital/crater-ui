# this module just shows a message if config secrets aren't set, to help the developer

module.exports = (config) ->
    unless config.gitlab_token? and config.jira_password?
        colors = require 'colors/safe'
        console.log ''
        console.log colors.bgYellow.black """
        .                                                                        .
        .  Looks like you haven't got your secrets loaded.                       .
        .  You need to export environment variables for each of these.           .
        .                                                                        .
        .  Search for "process.env" in config.coffee to see what's needed.       .
        .                                                                        .
        .  I'd recommend storing a note in your password manager with a load of  .
        .  lines like                                                            .
        .    export JIRA_PASSWORD='password123'                                  .
        .  that you can copy & paste into your  shell before starting Jiri.      .
        .                                                                        .
        """
        console.log ''

    # Assert some required config
    throw "JIRA_PASSWORD needs to be set in the environment" unless config.jira_password?
    throw "GITLAB_TOKEN needs to be set in the environment" unless config.gitlab_token?
    throw "GOOGLE_PRIVATE_KEY needs to be set in the environment" unless config.google_private_key?
    throw "GOOGLE_CLIENT_ID needs to be set in the environment" unless config.google_client_id?
    throw "GOOGLE_CLIENT_EMAIL needs to be set in the environment" unless config.google_client_email?
