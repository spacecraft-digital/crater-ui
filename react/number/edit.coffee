React = require 'react'

module.exports = React.createClass
    mixins: [require('../all/edit.coffee'), require('../scalar/edit.coffee')],
    render: require "../../views/properties/number/edit.rt"
