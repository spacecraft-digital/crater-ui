React = require 'react'
moment = require 'moment'

module.exports = React.createClass
    calendarFormats:
        lastDay: '[Yesterday]'
        sameDay: '[Today]'
        nextDay: '[Tomorrow]'
        lastWeek: '[last] dddd'
        nextWeek: '[++]'
        sameElse: '[++]'

    mixins: [require('../all/edit.coffee'), require('../scalar/edit.coffee')],
    render: require "../../views/properties/date/edit.rt"
    getMoment: ->
        m = moment @props.value
        now = moment()

        # set the time component to the current time (not used for the value,
        # but helps with relative date display)
        m.hour now.hour()
        m.minute now.minute()
        m.second now.second()

    # returns the date value as string in the form YYYY-MM-DD
    # suitable for input[type=date]
    getDateValue: ->
        return '' unless @props.value
        m = this.getMoment()
        return '' unless m.isValid()
        m.format('YYYY-MM-DD')

    # returns a string such as 'yesterday' or 'last Monday' for recent/soon dates,
    # and in the form of '2 months ago' for more distance dates
    getRelativeDate: ->
        return '' unless @props.value
        m = this.getMoment()
        return '' unless m.isValid()
        date = m.calendar moment(), @calendarFormats
        if date is '++'
            date = m.fromNow()
        date
