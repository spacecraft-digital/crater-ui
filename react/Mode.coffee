React = require 'react'

Mode = React.createClass
    getInitialState: ->
        mode: 'view'

    changeHandler: (ev) ->
        mode = ev.target.value
        this.props.onChange mode

    render: require '../views/mode.rt'

module.exports = Mode
