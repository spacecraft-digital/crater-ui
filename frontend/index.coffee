CraterUi = require './CraterUi.coffee'

document.addEventListener 'DOMContentLoaded', (ev) ->
    new CraterUi {
        collections: window.spacecraft.collections
        collection: window.location.pathname.split('/')[1]
        entities: window.spacecraft.entities
        schema: window.spacecraft.schema
        mainElement: '#main'
    }
