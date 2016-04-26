React = require 'react'
regexEscape = require 'escape-string-regexp'

module.exports = React.createClass
    mixins: [require('../all/edit.coffee'), require('../scalar/edit.coffee')],
    render: ->
        if this.props.schema.multiLine
            template = require "../../views/properties/string/edit--multiline.rt"
        else if this.props.schema.suggestions
            template = require "../../views/properties/string/edit--autocomplete.rt"
        else
            template = require "../../views/properties/string/edit.rt"
        return template.apply @, arguments

    getInitialState: ->
        suggestions: []

    changeHandler: (ev, o) ->
        @props.setState o.newValue

    blurHandler: (ev) ->
        @props.setState @input.value

    loadSuggestions: (input) ->
        return Promise.resolve(@suggestions) if @suggestions?

        fetch "/api/v1/customers?distinct=#{this.props.path.replace /\.\d+\./g, '.'}"
        .then (response) -> response.json()
        .then (data) =>
            @suggestions = data.filter((a) -> a.trim() != '').map (a) -> name: a

    getSuggestionValue: (suggestion) ->
        return suggestion.name

    onSuggestionsUpdateRequested: (o) ->
        {value: input, reason} = o
        @loadSuggestions input
        .then (suggestions) =>
            if input
                regex = new RegExp("(^|\\b)#{regexEscape input}", "i")
                suggestions = suggestions.filter (value) -> (value.name.length > input.length) && regex.test(value.name)
            @setState suggestions: suggestions

    inputKeyDownHandler: (ev) ->
        @lastKey = ev.key

    componentDidUpdate: (prevProps, prevState) ->
        if @state.suggestions.length is 1 and @lastKey is 'Unidentified'
            name = @state.suggestions[0].name
            typed = @input.value.toLowerCase()
            if name.toLowerCase().indexOf(typed) is 0
                @input.value = name
                @input.setSelectionRange typed.length, name.length

    renderSuggestion: (suggestion, o) ->
        input = if o.valueBeforeUpDown isnt null then o.valueBeforeUpDown else o.value

        regex = new RegExp("^(.*?)(#{regexEscape input})(.*)$", 'i')
        if input.length && m = suggestion.name.match regex
            return React.createElement 'span', {className: 'autosuggest__suggestion'},
                m[1],
                React.createElement 'span', {className: 'autosuggest__suggestion__highlight'}, m[2]
                m[3]
        else
            return React.createElement 'span', {className: 'autosuggest__suggestion__highlight'}, suggestion.name

    getTheme: ->
        container:                   'react-autosuggest__container'
        containerOpen:               'react-autosuggest__container--open'
        input:                       'form__control'
        suggestionsContainer:        'react-autosuggest__suggestions-container'
        suggestion:                  'react-autosuggest__suggestion'
        suggestionFocused:           'react-autosuggest__suggestion--focused'
        sectionContainer:            'react-autosuggest__section-container'
        sectionTitle:                'react-autosuggest__section-title'
        sectionSuggestionsContainer: 'react-autosuggest__section-suggestions-container'
