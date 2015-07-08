class Cable.Subscriptions
  constructor: (@consumer) ->
    @subscriptions = []

  add: (subscription) ->
    @subscriptions.push(subscription)
    @notify(subscription, "initialized")
    if @sendCommand(subscription, "subscribe")
      @notify(subscription, "connected")

  reload: ->
    for subscription in @subscriptions
      if @sendCommand(subscription, "subscribe")
        @notify(subscription, "connected")

  remove: (subscription) ->
    @sendCommand(subscription, "unsubscribe")
    @subscriptions = (s for s in @subscriptions when s isnt subscription)

  notifyAll: (callbackName, args...) ->
    for subscription in @subscriptions
      @notify(subscription, callbackName, args...)

  notify: (subscription, callbackName, args...) ->
    if typeof subscription is "string"
      subscriptions = (s for s in @subscriptions when s.identifier is subscription)
    else
      subscriptions = [subscription]

    for subscription in subscriptions
      subscription[callbackName]?(args...)

  sendCommand: (subscription, command) ->
    {identifier} = subscription
    if identifier is Cable.PING_IDENTIFIER
      @consumer.connection.isOpen()
    else
      @consumer.send({command, identifier})

  toJSON: ->
    subscription.identifier for subscription in @subscriptions
