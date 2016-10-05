_ = require 'lodash'

React = require 'react'

module.exports = React.createClass
    mixins: [require '../all/edit.coffee'],
    render: require "../../views/properties/array/edit.rt"
    addChild: ->
        a = this.props.value||[]
        switch @props.schema.childType
            when 'Object'
                a.push {}
            when 'Array'
                a.push []
            when 'String'
                a.push ''
            when 'Boolean'
                a.push false
            when 'Date'
                a.push new Date
            when 'Number'
                a.push 0

        @props.setState a

        _.defer => document.dispatchEvent new CustomEvent 'crater:focus', detail: path: "#{@props.path}.#{a.length-1}"

    removeChild: (childIndex, ev) ->
        a = this.props.value
        a.splice childIndex, 1
        @props.setState a

    setFocusHandler: (ev) ->
        if ev.detail?.path is @props.path
            ev.stopPropagation()
            document.dispatchEvent new CustomEvent 'crater:focus', detail: path: @props.children[0].props.path

    componentWillMount: ->
        # ensure value is not undefined so the component is “controlled” (in React terms)
        this.props.value = [] if typeof this.props.value is 'undefined'
