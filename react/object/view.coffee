React = require 'react'
slug = require 'slug'
ucfirst = require 'ucfirst'
i = require('i')()

module.exports = React.createClass

    render: ->
        if this.props.schema?.isCompactible
            return require('../../views/properties/object/view--compact.rt').apply this, arguments
        else
            return require('../../views/properties/object/view.rt').apply this, arguments

    getChildTypeClassName: (child) ->
        typeSlug = slug child.props.schema.type.toLowerCase()
        className = "object__property--#{typeSlug}"
        if child.props.schema.childType
            arrayOfType = slug child.props.schema.childType.toLowerCase()
            className += " object__property--array-of-#{arrayOfType}"
        if child.props.name is this.props.schema?.nameProperty
            className += " object__property--name"
        className

    getChildLabel: (child) ->
        label = ucfirst child.props.label
        # returns singular label if there's just a single array item
        if child.props.schema.type is 'Array' and child.props.value.length is 1
            label = i.singularize label
        label
