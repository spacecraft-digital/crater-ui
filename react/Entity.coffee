uncamelize = require('uncamelize') specialCases: 'DB', merge: 'specialCases'
ucfirst = require 'ucfirst'
_ = require 'lodash';

React = require 'react'
Crater = require 'crater/lib/Crater'

Entity = React.createClass
    typeTemplates:
        array:
            'view': require './array/view.coffee'
            'edit': require './array/edit.coffee'
        object:
            'view': require './object/view.coffee'
            'edit': require './object/edit.coffee'
        string:
            'view': require './string/view.coffee'
            'edit': require './string/edit.coffee'
        date:
            'view': require './date/view.coffee'
            'edit': require './date/edit.coffee'
        boolean:
            'view': require './boolean/view.coffee'
            'edit': require './boolean/edit.coffee'
        number:
            'view': require './number/view.coffee'
            'edit': require './number/edit.coffee'

    getInitialState: ->
        data: {}
        mode: 'view'

    getPropertyPath: (parentPath, childName) ->
        (if parentPath then "#{parentPath}." else '') + childName

    setDataPath: (path, value) ->
        data = @props.data
        _.set data, path, value
        @props.setData data

    propertySetState: (path, value) ->
        @setDataPath path, value
        @props.changeHandler path, value

    propertyInputChangeHandler: (path, ev) ->
        @propertySetState path, ev.target.value

    createComponentForProperty: (name, schema, value, parentPath = '', breadcrumbs = []) ->
        return null unless schema

        path = @getPropertyPath parentPath, name
        label = uncamelize String(name)

        pathSteps = path.replace(/\.\d+/g, '').split '.'

        props =
            path: path
            key: path
            label: label
            name: name
            value: value
            schema: schema
            breadcrumbs: breadcrumbs
            depth: pathSteps.length
            setState: _.curry(@propertySetState) path
            changeHandler: _.curry(@propertyInputChangeHandler) path
            editHandler: _.curry(@props.pathEditHandler, 2) path

        view = @props.mode

        switch schema.type
            when 'Array'
                children = _.compact @createArrayChildren schema, value, path, breadcrumbs
                return React.createElement @typeTemplates.array[view], props, children
            when 'Object'
                breadcrumbs = breadcrumbs.concat [ucfirst schema.heading] if schema.heading
                children = @createObjectChildren schema.children, value, path, breadcrumbs
                return React.createElement @typeTemplates.object[view], props, children
            when 'Boolean'
                props.value = true if props.value is 'true'
                props.value = false if props.value is 'false'
                return React.createElement @typeTemplates[schema.type.toLowerCase()][view], props
            when 'String', 'Date', 'Number'
                return React.createElement @typeTemplates[schema.type.toLowerCase()][view], props
            when 'ObjectID'
                return null
            else
                # ignore types we can't handle
                return null

    # if all the following are true
    #   there is a property named 'name' or 'role'
    #   there are two non-meta properties
    #   both of these properties are strings
    # returns 'name' or 'role'
    # else returns false
    objectIsCompactible: (schema) ->
        return false unless schema
        count = 0
        for key, o of schema when key not in ['_id', '__v']
            return false if o.type isnt 'String'
            count++
        return count is 2

    createObjectChildren: (schema, value = {}, path = '', breadcrumbs = []) ->
        children = for own key, branch of schema when key not in ['_id', '__v']
            continue if @props.mode is 'view' and (!value[key] or value[key]?.length is 0)
            @createComponentForProperty key, branch, value[key], path, breadcrumbs
        _.compact children

    # schema is an object
    # value is an array
    # path is a string
    createArrayChildren: (schema, value = [], path = '', breadcrumbs = []) ->
        schemaDef = Crater.getSchema schema.childMeta?.name
        compactible = schemaDef && schemaDef.statics?.getNameProperty() && @objectIsCompactible schema.childSchema
        for item, index in value
            childSchema =
                type: schema.childType
                children: schema.childSchema
                heading: schemaDef.methods.getName.call item, true if schemaDef
                isCompactible: compactible
            @createComponentForProperty index, childSchema, item, path, breadcrumbs

    render: require '../views/entity.rt'

module.exports = Entity
