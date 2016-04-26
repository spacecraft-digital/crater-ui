React = require 'react'
moment = require 'moment'

module.exports = React.createClass
    mixins: [require('../scalar/view.coffee')],
    render: require "../../views/properties/date/view.rt"
    getMoment: ->
        moment @props.value