class Cable.SubscriberManager
  constructor: (@cable) ->
    @subscribers = {}

  add: (subscriber) ->
    {identifier} = subscriber
    @subscribers[identifier] = subscriber
    @notify(subscriber, "initialized")
    if @sendCommand("subscribe", identifier)
      @notify(subscriber, "connected")

  reload: ->
    for identifier, subscriber of @subscribers
      if @sendCommand("subscribe", identifier)
        @notify(subscriber, "connected")

  remove: (subscriber) ->
    {identifier} = subscriber
    @sendCommand("unsubscribe", identifier)
    delete @subscribers[identifier]

  notifyAll: (callbackName, args...) ->
    for identifier, subscriber of @subscribers
      @notify(subscriber, callbackName, args...)

  notify: (subscriber, callbackName, args...) ->
    if typeof subscriber is "string"
      subscriber = @subscribers[subscriber]

    if subscriber
      subscriber[callbackName]?(args...)

  sendCommand: (command, identifier) ->
    return true if identifier is Cable.PING_IDENTIFIER
    @cable.send({command, identifier})
