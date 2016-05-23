CraterUi = require './CraterUi.coffee'

document.addEventListener 'DOMContentLoaded', (ev) ->
    new CraterUi {
        entities: window.spacecraft.entities
        schema: window.spacecraft.schema
        mainElement: '#main'
    }
