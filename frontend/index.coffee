CraterUi = require '../src/CraterUi.coffee'

document.addEventListener 'DOMContentLoaded', (ev) ->
    new CraterUi {
        customers: window.spacecraft.customers
        schema: window.spacecraft.customerSchema
        mainElement: '#main'
    }
