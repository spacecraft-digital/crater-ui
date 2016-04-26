# mixin for all edit views
module.exports =
    componentDidMount: ->
        document.addEventListener 'crater:focus', @setFocusHandler
