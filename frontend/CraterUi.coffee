React = require 'react'
ReactDOM = require 'react-dom'
_ = require 'lodash'
slug = require 'slug'
ReactTooltip = require 'react-tooltip'
inflect = require('i')()
ucfirst = require 'ucfirst'
regexEscape = require 'escape-string-regexp'

# keymaster handles keyboard shortcuts — loads into global scope as key
key = require 'keymaster'

MainReactClass = require '../react/Main.coffee'

class CraterUi
    activeEntity: null
    activeSnapshot: null
    snapshotCount: 0

    constructor: (options) ->
        @options = _.extend
            collection: null,

            # selector for entity DOM element
            mainElement: ''

            # array of collection names
            collections: []
            # array of entity IDs and names
            entities: []
            # data schema to build UI from
            schema: {}

            # seconds to wait before saving in case something else is changed in the meantime
            saveDelay: 2
            # maximum number of seconds to wait before saving after a data change
            maxSaveDelay: 25

            snapshotDelay: 2

            # a function that returns a load URL, passed the entity ID
            loadUrl: @getLoadUrl

            # a function that returns a save URL, passed the entity ID
            saveUrl: @getSaveUrl

            undoLevels: 200
        , options || {}

        @entityType = inflect.singularize @options.collection

        @domEls =
            main: @findElement @options.mainElement

        @renderMainComponent()

        entityToLoad = entity for entity in @options.entities when @getEntityUrl(entity) is window.location.pathname
        if entityToLoad
            @load entityToLoad.id
            @setMode @retrieve('mode') if @retrieve('mode')
        else
            @close true

        window.addEventListener 'popstate', @historyStateChange

        @domEls.search.addEventListener 'focus', @searchFocus
        @domEls.search.addEventListener 'blur', @blurTimer = _.defer @searchBlur
        @domEls.search.addEventListener 'keydown', @searchKeydown
        @domEls.search.addEventListener 'keyup', @searchKeyup
        document.addEventListener 'keydown', @documentKeydown

        @saveDebounced = _.debounce @save, @options.saveDelay*1000, maxWait: @options.maxSaveDelay*1000

        @setUndoRedoState()

        @initShortcuts()

    renderMainComponent: ->
        reactElement = React.createElement MainReactClass,
            entities: @options.entities
            schema: @options.schema
            entitySelectHandler: @entitySelectHandler
            changeHandler: @changeHandler
            pathEditHandler: @goToEditMode
            modeChangeHandler: @modeChangeHandler
            deleteClickHandler: @deleteClickHandler
            searchResultClickHandler: @searchResultClickHandler
            newClickHandler: @newClickHandler
            backClickHandler: @backClickHandler
            setData: @setStateData
            undoClickHandler: @undo
            redoClickHandler: @redo
            collection: @options.collection
            entityType: @entityType
            apiUrl: @getSaveUrl()
            collections: @options.collections

        @component = ReactDOM.render reactElement, @domEls.main
        @domEls.search = @findElement @options.searchElement

    initShortcuts: =>
        key.filter = (event) ->
            tagName = (event.target || event.srcElement).tagName;
            key.setScope if /^(INPUT|TEXTAREA|SELECT)$/.test(tagName) then 'input' else 'other'
            return true

        key '⌘+z, ctrl+z', (ev) => ev.preventDefault(); @undo()
        key '⌘+shift+z, ctrl+shift+z', @redo
        key 'escape', 'other', =>
            if @getMode() is 'edit'
                @setMode 'view'
            else
                @close()
        key 'escape', 'input', (ev) =>
            if @component.state.searching
                @cancelSearch()
            else
                ev.target.blur()
        key '⌘+e, ctrl+e', @setMode.bind @, 'edit'
        key '⌘+s, ctrl+s', 'all', (ev) => ev.preventDefault(); @save()

    historyStateChange: (ev) =>
        if ev.state?.id
            @load ev.state.id
        else
            @close()

    documentKeydown: (ev) =>
        if ev.target is document.body and ev.code.match(/^(Key|Digit|Enter)/) and not (ev.altKey or ev.ctrlKey or ev.metaKey or ev.shiftKey)
            @domEls.search.value = '';
            @domEls.search.focus();
            ev.stopPropagation()

    searchFocus: (ev) =>
        clearTimeout @blurTimer if @blurTimer
        @component.setState searching: true
        @search @domEls.search.value, true

    searchBlur: (ev) =>
        @component.setState searching: false, searchResults: []
        @domEls.search.value = '';

    searchKeydown: (ev) =>
        if ev.code in ['ArrowUp', 'ArrowDown']
            delta = if ev.code is 'ArrowUp' then -1 else 1
            selectedIndex = @component.state.selectedSearchResult + delta
            selectedIndex = Math.max Math.min(@component.state.searchResults.length-1, selectedIndex), 0
            @component.setState selectedSearchResult: selectedIndex
            ev.preventDefault()
            ev.stopPropagation()
        else if ev.code is 'Enter'
            id = @component.state.searchResults[@component.state.selectedSearchResult]?.id
            if id
                @load id
                @cancelSearch()
                ev.stopPropagation()

    searchKeyup: (ev) =>
        @search @domEls.search.value

    searchResultClickHandler: (ev) =>
        @cancelSearch()
        @load ev.target.dataset.searchResultId if ev.target.dataset.searchResultId

    cancelSearch: =>
        @component.setState searchResults: []
        @searchBlur()
        @domEls.search.blur()

    # returns the DOM element matching `selector`,
    # but allows for a DOM element to be passed through unchanged
    findElement: (selector, assert = true) ->
        if typeof selector is 'string' and selector isnt ''
            el = document.querySelector selector
            if assert and not el
                throw new Error "No DOM element found for selector '#{selector}'"
            return el
        return selector

    getLoadUrl: (id) =>
        "/api/v1/#{@options.collection}/#{id}"

    getSaveUrl: (id) =>
        base = "/api/v1/#{@options.collection}"
        if id then "#{base}/#{id}" else base

    getEntityUrl: (data) =>
        url = "/#{@options.collection}"
        if data
            nameSlug = slug (data.name||'new').toLowerCase()
            url += "/#{nameSlug}"
        url

    setMessage: (message, time = null) =>
        clearTimeout @messageClearTimer if @messageClearTimer
        @component.setState message: message
        if time
            @messageClearTimer = _.delay @clearMessage, time*1000

    clearMessage: =>
        @setMessage ''

    getActiveEntityId: =>
        @retrieve @options.collection

    setActiveEntity: (data) =>
        @component.setState displayEntity: true
        if data._id is @getActiveEntityId()
            history.replaceState {id: data._id}, data.name, @getEntityUrl data
        else
            @store @options.collection, data._id
            history.pushState {id: data._id}, data.name, @getEntityUrl data
        document.title = data.name or "Untitled #{@entityType}"

    getStateData: =>
        @component.state.data

    setStateData: (data) =>
        # sort stages into logical order
        data.projects[i].stages = @sortStages project.stages for project, i in data.projects if data.projects
        @component.setState data: data

    emptyStateData: ->
        @setStateData {}

    # takes an array of Stages (i.e. objects with names like QA, UAT)
    # and returns them in the order that we deploy to
    sortStages: (stages = []) ->
        stages.sort (a, b) ->
            # stages with these names will be order in this order.
            # Any other names will be put first
            stageOrder = ['dev','qa','uat','production']
            aPos = stageOrder.indexOf (a.name||'').toLowerCase()
            bPos = stageOrder.indexOf (b.name||'').toLowerCase()
            return aPos - bPos

    search: (query, force) =>
        query = query.toLowerCase()

        # don't bother running same search twice
        return if query is @searchQuery and not force
        @searchQuery = query

        startOfWordRegex = new RegExp " #{regexEscape query}", 'i'
        results = []
        for entity in @options.entities
            score = 0
            lcname = entity.name.toLowerCase().trim()

            if query is ''
                score = 1
            else
                index = lcname.indexOf(query)
                # scores for ranking
                score += 3 if index is 0
                score += 2 if entity.name.match startOfWordRegex
                score += 1 if index isnt -1

            if score > 0
                results.push id: entity.id, name: entity.name, lcname: lcname, score: score

        results.sort (one, two) ->
            cmp = two.score - one.score
            return cmp if cmp isnt 0
            return 0 if two.lcname is one.lcname
            # sort alphabetically (case insensitive)
            return if two.lcname > one.lcname then -1 else 1

        selectedIndex = if results.length is 1 then 0 else -1
        @component.setState searchResults: results, selectedSearchResult: selectedIndex

    load: (customerId) =>
        return @loadNew() if typeof customerId is 'undefined'

        @setMessage 'Loading…'

        fetch @options.loadUrl customerId
        .then (response) -> response.json()
        .then @loadData

    loadData: (data) =>
        @setActiveEntity data
        @lastSavedData = _.clone data
        @setStateData data
        @snapshot()
        @clearMessage()

    loadNew: =>
        @setMessage 'Loading…'
        @loadData name: "New #{@entityType}"
        # switch to edit mode and focus name element
        @goToEditMode 'name', true

    close: (replaceState = false) =>
        @component.setState displayEntity: false
        @store @options.collection, null
        if replaceState
            history.replaceState {}, 'Crater', @getEntityUrl()
        else
            history.pushState {}, 'Crater', @getEntityUrl()
        document.title = 'Crater'
        process.nextTick =>
            @domEls.search.focus()
            @searchFocus()

    save: (data) =>
        @saveDebounced.cancel()

        data = data || _.clone @getStateData()

        # don't save if no change has been made
        if @lastSavedData && _.isEqual data, @lastSavedData
            @setMessage 'Saved', 2

        nameHasChanged = @lastSavedData?.name isnt data.name
        @lastSavedData = _.clone data

        @setMessage 'Saving…'

        id = @getActiveEntityId()

        fetch @options.saveUrl(id),
            method: if id? then 'PATCH' else 'POST'
            headers: 'content-type': 'application/json'
            body: JSON.stringify data
        .then (response) =>
            if response.ok
                @setMessage 'Saved', 2

                response.json().then (entity) =>
                    if not id
                        @options.entities.push id: entity._id, name: entity.name
                        @loadData entity
                    else if nameHasChanged
                        for e, i in @options.entities when e.id is id
                            @options.entities[i].name = entity.name
                    @component.render() if nameHasChanged
            else
                @setMessage response.statusText
        .catch (err) =>
            @setMessage 'Save failed', 5

    delete: (id, name) =>
        return unless confirm "Sure you want to delete #{name}?"

        @setMessage "Deleting #{name}…"
        fetch @options.saveUrl(id),
            method: 'DELETE'
        .then (response) =>
            if response.ok
                @setMessage "#{name} has been deleted", 2
                @close()
                for e, i in @options.entities when e.id is id
                    @options.entities.splice i, 1
                    break
                @renderMainComponent()
            else
                @setMessage response.statusText, 5
        .catch (err) =>
            @setMessage "Failed to delete #{name}", 5

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
        return "snapshots-#{@getActiveEntityId()}"

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
        return 'view' unless @component.state.displayEntity
        @component.state.mode

    setMode: (mode) =>
        state =
            mode: mode
            undoable: @isUndoable()
            redoable: @isRedoable()
        @component.setState mode: mode
        @store 'mode', mode
        if mode is 'view' and not @getActiveEntityId()
            @close()

    store: (key, value, type = 'string') =>
        switch type
            when 'array', 'object'
                value = JSON.stringify value
        if value?
            sessionStorage[key] = value
        else
            delete sessionStorage[key]

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

    backClickHandler: (ev) =>
        ev.preventDefault()
        @close()

    newClickHandler: (ev) =>
        @cancelSearch()
        @loadNew()

    deleteClickHandler: (ev) =>
        return unless @component.state.data._id
        @delete @component.state.data._id, @component.state.data.name
        ReactTooltip.hide()

    modeChangeHandler: (ev) =>
        mode = if ev.target.checked then 'edit' else 'view'
        @setMode mode

    goToEditMode: (focusPath, select = false) =>
        @setMode 'edit'
        _.defer ->
            el = document.getElementById focusPath
            el.focus()
            el.select() if select

    entitySelectHandler: (ev) =>
        if ev.target.value is ''
            @loadNew()
        else
            @load ev.target.value

module.exports = CraterUi
