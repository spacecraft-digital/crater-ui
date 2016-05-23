# mixin for scalar view views
module.exports =
    clickHandler: (ev) ->
        ev.target.select()
