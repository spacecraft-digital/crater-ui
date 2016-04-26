# mixin for scalar view views
module.exports =
    clickHandler: (ev) ->
        console.log 'click!'
        ev.target.select()
