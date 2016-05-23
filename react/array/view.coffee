React = require 'react'

module.exports = React.createClass
    render: require "../../views/properties/array/view.rt"

    getChildTypeClassName: (child) ->
        className = ""
        if child.props.schema?.isCompactible
            className += " array__item--compactible"
        className
