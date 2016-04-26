React = require 'react'

module.exports = React.createClass
    mixins: [require('../scalar/view.coffee')],
    render: require "../../views/properties/boolean/view.rt"
