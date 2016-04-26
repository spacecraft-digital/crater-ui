React = require 'react'

module.exports = React.createClass
    mixins: [require '../all/edit.coffee'],
    render: require "../../views/properties/object/edit.rt"

    setFocusHandler: (ev) ->
        if ev.detail?.path is @props.path
            ev.stopPropagation()
            document.dispatchEvent new CustomEvent 'crater:focus', detail: path: @props.children[0].props.path
