class Cable.Channel
  constructor: (@cable, params = {}, mixin) ->
    @identifier = JSON.stringify(params)
    extend(this, mixin)
    @cable.subscribers.add(this)

  # Perform a channel action with the optional data passed as an attribute
  perform: (action, data = {}) ->
    data.action = action
    @send(data)

  send: (data) ->
    @cable.send(command: "message", identifier: @identifier, data: JSON.stringify(data))

  unsubscribe: ->
    @cable.subscribers.remove(this)

  extend = (object, properties) ->
    if properties?
      for key, value of properties
        object[key] = value
    object
