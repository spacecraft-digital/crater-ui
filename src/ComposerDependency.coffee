https = require 'https'
config = require '../config'

class ComposerDependency
    constructor: (@name) ->

    getJson: ->
        url = config.toran_proxy_package_url.replace '#{package_name}', @name
        https.get url, (response) ->
            if response.statusCode is 200
                s = ''
                response.on 'data', (chunk) -> s += chunk
                response.on 'end', =>
                    ComposerJson = require './src/ComposerJson'
                    composerJson = new ComposerJson s
                    res.json composerJson.getDependencies()
            else
                res.status(500).send("Unable to retrieve #{encode url}")

module.exports = ComposerDependency
