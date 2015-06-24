class @Cable.Channel
  constructor: (@cable, params = {}, mixin) ->
    @identifier = JSON.stringify(params)
    extend(this, mixin)
    @subscribe(@identifier, this)

  # Perform a channel action with the optional data passed as an attribute
  sendAction: (action, data = {}) ->
    data.action = action
    @sendMessage(data)

  sendMessage: (data) ->
    @cable.sendMessage(@identifier, JSON.stringify(data))

  subscribe: ->
    @cable.subscribe(@identifier, this)

  unsubscribe: ->
    @cable.unsubscribe(@identifier)

  extend = (object, properties) ->
    if properties?
      for key, value of properties
        object[key] = value
    object
