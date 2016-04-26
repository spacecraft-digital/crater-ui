# mixin for scalar edit views
module.exports =
    componentWillMount: ->
        # ensure value is not undefined so the component is “controlled” (in React terms)
        this.props.value = null if typeof this.props.value is 'undefined'

    setInput: (input) ->
        @input = input

    setFocusHandler: (ev) ->
        if @input and ev.detail?.path is @props.path
            @input.focus()
            ev.stopPropagation()
