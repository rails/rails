class Cable.SubscriberManager
  constructor: (@consumer) ->
    @subscribers = []

  add: (subscriber) ->
    @subscribers.push(subscriber)
    @notify(subscriber, "initialized")
    if @sendCommand(subscriber, "subscribe")
      @notify(subscriber, "connected")

  reload: ->
    for subscriber in @subscribers
      if @sendCommand(subscriber, "subscribe")
        @notify(subscriber, "connected")

  remove: (subscriber) ->
    @sendCommand(subscriber, "unsubscribe")
    @subscribers = (s for s in @subscribers when s isnt subscriber)

  notifyAll: (callbackName, args...) ->
    for subscriber in @subscribers
      @notify(subscriber, callbackName, args...)

  notify: (subscriber, callbackName, args...) ->
    if typeof subscriber is "string"
      subscribers = (s for s in @subscribers when s.identifier is subscriber)
    else
      subscribers = [subscriber]

    for subscriber in subscribers
      subscriber[callbackName]?(args...)

  sendCommand: (subscriber, command) ->
    {identifier} = subscriber
    if identifier is Cable.PING_IDENTIFIER
      @consumer.connection.isOpen()
    else
      @consumer.send({command, identifier})

  toJSON: ->
    subscriber.identifier for subscriber in @subscribers
