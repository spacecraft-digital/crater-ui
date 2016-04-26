React = require 'react'
ReactDOM = require 'react-dom'
_ = require 'lodash'
slug = require 'slug'
ReactTooltip = require 'react-tooltip'

# keymaster handles keyboard shortcuts — loads into global scope as key
key = require 'keymaster'

MainReactClass = require '../react/Main.coffee'

class CraterUi
    activeCustomer: null
    activeSnapshot: null
    snapshotCount: 0

    constructor: (options) ->
        @options = _.extend
            # selector for customer DOM element
            mainElement: ''

            # array of customer IDs and names
            customers: []
            # data schema to build UI from
            schema: {}

            # seconds to wait before saving in case something else is changed in the meantime
            saveDelay: 2
            # maximum number of seconds to wait before saving after a data change
            maxSaveDelay: 25

            snapshotDelay: 2

            # a function that returns a load URL, passed the customer ID
            loadUrl: @getLoadUrl

            # a function that returns a save URL, passed the customer ID
            saveUrl: @getSaveUrl

            undoLevels: 200
        , options || {}

        @domEls =
            main: @findElement @options.mainElement

        reactElement = React.createElement MainReactClass,
            customers: @options.customers
            schema: @options.schema
            customerSelectHandler: @customerSelectHandler
            changeHandler: @changeHandler
            pathEditHandler: @goToEditMode
            modeChangeHandler: @modeChangeHandler
            setData: @setStateData
            undoClickHandler: @undo
            redoClickHandler: @redo

        @component = ReactDOM.render reactElement, @domEls.main

        @setMode @retrieve('mode') if @retrieve('mode')
        @load activeCustomerId if activeCustomerId = @getActiveCustomerId()

        window.addEventListener 'popstate', @historyStateChange

        @saveDebounced = _.debounce @save, @options.saveDelay*1000, maxWait: @options.maxSaveDelay*1000

        @setUndoRedoState()

        @initShortcuts()

    initShortcuts: =>
        key.filter = (event) ->
            tagName = (event.target || event.srcElement).tagName;
            key.setScope if /^(INPUT|TEXTAREA|SELECT)$/.test(tagName) then 'input' else 'other'
            return true

        key '⌘+z, ctrl+z', (ev) => ev.preventDefault(); @undo()
        key '⌘+shift+z, ctrl+shift+z', @redo
        key 'escape', 'other', @setMode.bind @, 'view'
        key 'escape', 'input', (ev) -> ev.target.blur()
        key '⌘+e, ctrl+e', @setMode.bind @, 'edit'
        key '⌘+s, ctrl+s', 'all', (ev) => ev.preventDefault(); @save()

    historyStateChange: (ev) =>
        @load ev.state?.id

    # returns the DOM element matching `selector`,
    # but allows for a DOM element to be passed through unchanged
    findElement: (selector, assert = true) ->
        if typeof selector is 'string' and selector isnt ''
            el = document.querySelector selector
            if assert and not el
                throw new Error "No DOM element found for selector '#{selector}'"
            return el
        return selector

    getLoadUrl: (id) ->
        "/api/v1/customers/#{id}"

    getSaveUrl: (id) ->
        "/api/v1/customers/#{id}"

    setMessage: (message, time = null) =>
        clearTimeout @messageClearTimer if @messageClearTimer
        @component.setState message: message
        if time
            @messageClearTimer = _.delay @clearMessage, time*1000

    clearMessage: =>
        @setMessage ''

    getActiveCustomerId: =>
        @retrieve 'customer'

    setActiveCustomer: (data) =>
        return if data._id is @getActiveCustomerId()
        @store 'customer', data._id
        history.pushState {id: data._id}, data.name, "/#{slug data.name.toLowerCase()}"
        document.title = data.name

    getStateData: =>
        @component.state.data

    setStateData: (data) =>
        # sort stages into logical order
        data.projects[i].stages = @sortStages project.stages for project, i in data.projects
        @component.setState data: data

    emptyStateData: ->
        @setStateData {}

    # takes an array of Stages (i.e. objects with names like QA, UAT)
    # and returns them in the order that we deploy to
    sortStages: (stages) ->
        stages.sort (a, b) ->
            # stages with these names will be order in this order.
            # Any other names will be put first
            stageOrder = ['dev','qa','uat','production']
            aPos = stageOrder.indexOf (a.name||'').toLowerCase()
            bPos = stageOrder.indexOf (b.name||'').toLowerCase()
            return aPos - bPos

    load: (customerId) =>
        @setMessage 'Loading…'

        fetch @options.loadUrl customerId
        .then (response) -> response.json()
        .then (data) =>
            @setActiveCustomer data
            @setStateData data
            @snapshot()
            @clearMessage()

    save: (data) =>
        @saveDebounced.cancel()

        # don't save if no change has been made
        return if @lastSavedData && _.isEqual data, @lastSavedData
        @lastSavedData = data

        @setMessage 'Saving…'

        fetch @options.saveUrl(@getActiveCustomerId()),
            method: 'post',
            headers:
                'content-type': 'application/json'
            body: JSON.stringify @getStateData()
        .then (response) =>
            if response.ok
                @setMessage 'Saved', 2
            else
                @setMessage response.statusText
        .catch (err) =>
            @setMessage 'Save failed', 5

    snapshot: =>
        snapshots = @retrieveSnapshots()

        lastSnapshot = snapshots[snapshots.length - 1]
        snapshot = JSON.stringify @getStateData()

        # don't snapshot if no change
        return if snapshot is lastSnapshot

        # make space for another snapshot if we're at maximum levels
        snapshots.shift() if snapshots.length >= @options.undoLevels

        # if there are 'redo' levels, remove them
        if @activeSnapshot < @snapshotCount-1
            snapshots = snapshots.slice 0, @activeSnapshot+1

        snapshots.push snapshot

        @snapshotCount = snapshots.length
        @activeSnapshot = snapshots.length-1

        @store @getSnapshotKeyName(), snapshots, 'array'

        @setUndoRedoState()

    undo: =>
        return unless @isUndoable()
        @restoreSnapshot @activeSnapshot - 1

    redo: =>
        return unless @isRedoable()
        @restoreSnapshot @activeSnapshot + 1

    isUndoable: =>
        @getMode() is 'edit' and @activeSnapshot > 0

    isRedoable: =>
        @getMode() is 'edit' and @activeSnapshot < (@snapshotCount - 1)

    setUndoRedoState: =>
        state =
            undoable: @isUndoable()
            redoable: @isRedoable()
        @component.setState state

    getSnapshotKeyName: () ->
        return "snapshots-#{@getActiveCustomerId()}"

    restoreSnapshot: (index) ->
        @saveDebounced.cancel()
        snapshots = @retrieveSnapshots()
        data = JSON.parse snapshots[index]
        @setStateData data
        @saveDebounced()
        @activeSnapshot = index
        @setUndoRedoState()

    retrieveSnapshots: =>
        @retrieve @getSnapshotKeyName(), 'array'

    getMode: =>
        @component.state.mode

    setMode: (mode) =>
        state =
            mode: mode
            undoable: @isUndoable()
            redoable: @isRedoable()
        @component.setState mode: mode
        @store 'mode', mode

    store: (key, value, type = 'string') =>
        switch type
            when 'array', 'object'
                value = JSON.stringify value
        sessionStorage[key] = value

    retrieve: (key, type = 'string') =>
        switch type
            when 'array'
                return JSON.parse sessionStorage[key] || '[]'
            when 'object'
                return JSON.parse sessionStorage[key] || '{}'
            when 'number'
                return Number sessionStorage[key]
            else
                return sessionStorage[key]

    changeHandler: (path, value) =>
        @snapshot()
        @saveDebounced()
        ReactTooltip.hide()

    modeChangeHandler: (ev) =>
        mode = if ev.target.checked then 'edit' else 'view'
        console.log mode
        @setMode mode

    goToEditMode: (focusPath) =>
        @setMode 'edit'
        _.defer ->
            el = document.getElementById focusPath
            el.focus()

    customerSelectHandler: (ev) =>
        @load ev.target.value

module.exports = CraterUi
