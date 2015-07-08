class Cable.Subscription
  constructor: (@subscriptions, params = {}, mixin) ->
    @identifier = JSON.stringify(params)
    extend(this, mixin)
    @subscriptions.add(this)
    @consumer = @subscriptions.consumer

  # Perform a channel action with the optional data passed as an attribute
  perform: (action, data = {}) ->
    data.action = action
    @send(data)

  send: (data) ->
    @consumer.send(command: "message", identifier: @identifier, data: JSON.stringify(data))

  unsubscribe: ->
    @subscriptions.remove(this)

  extend = (object, properties) ->
    if properties?
      for key, value of properties
        object[key] = value
    object
