class @Cable.Channel
  constructor: (@cable, params = {}, mixin) ->
    @identifier = JSON.stringify(params)
    extend(this, mixin)

    @cable.subscribe @identifier,
      onConnect: => @connected?()
      onDisconnect: => @disconnected?()
      onReceiveData: (data) => @receive?(data)

  # Perform a channel action with the optional data passed as an attribute
  perform: (action, data = {}) ->
    data.action = action
    @cable.sendData(@identifier, JSON.stringify(data))

  send: (data) ->
    @cable.sendData(@identifier, JSON.stringify(data))

  close: ->
    @cable.unsubscribe(@identifier)

  extend = (object, properties) ->
    if properties?
      for key, value of properties
        object[key] = value
    object
