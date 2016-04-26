React = require 'react'
$ = require 'npm-zepto'
window.jQuery = window.$
window.jQuery.fn.outerHeight = -> $(this).height()
window.jQuery.fn.outerWidth = window.jQuery.fn.width
stickyKit = require 'sticky-kit/dist/sticky-kit'
_ = require 'lodash'

Main = React.createClass
    getInitialState: ->
        mode: 'view'
        data: {}
        undoable: false
        redoable: false

    componentDidUpdate: ->
        @initStickyHeadings()

    initStickyHeadings: ->
        $(".sticky").stick_in_parent
            inner_scrolling: false
            offset_top: $('#header').height() + 17
            parent: 'li'
            sticky_class: 'sticky--stuck'
        .on 'sticky_kit:bottom', (ev) -> ev.target.classList.add('sticky--bottomed')
        .on 'sticky_kit:unbottom', (ev) -> ev.target.classList.remove('sticky--bottomed')

    render: require '../views/main.rt'

module.exports = Main
