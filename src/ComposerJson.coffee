class ComposerJson
    ignoreDeps: [
        'php'
        'doctrine/migrations'
        'jadu/meteor'
        'jadu/jaduframework' 
        'twig/twig'
        'twig/extensions'
        'jadu/pulsar'
        'jadu/pulsar-fonts'
        'klein/klein' 
        'ircmaxell/password-compat'
        'nesbot/carbon'
        'ddeboer/data-import'
        'jasig/phpcas'
        'symfony/polyfill'
    ]

    constructor: (json) ->
        @object = JSON.parse json

    # returns the require block, unchanged
    getAllDependencies: ->
        @object.require

    # returns the dependencies, filtering out known common ones
    getDependencies: =>
        deps = {}
        for own dep, version of @object.require
            deps[dep] = version unless dep in @ignoreDeps
        deps

module.exports = ComposerJson
