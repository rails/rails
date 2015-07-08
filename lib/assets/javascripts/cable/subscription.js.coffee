class Cable.Subscription
  constructor: (@consumer, params = {}, mixin) ->
    @identifier = JSON.stringify(params)
    extend(this, mixin)
    @consumer.subscriptions.add(this)

  # Perform a channel action with the optional data passed as an attribute
  perform: (action, data = {}) ->
    data.action = action
    @send(data)

  send: (data) ->
    @consumer.send(command: "message", identifier: @identifier, data: JSON.stringify(data))

  unsubscribe: ->
    @consumer.subscriptions.remove(this)

  extend = (object, properties) ->
    if properties?
      for key, value of properties
        object[key] = value
    object
