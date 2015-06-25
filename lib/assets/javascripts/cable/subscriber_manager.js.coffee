class Cable.SubscriberManager
  constructor: (@cable) ->
    @subscribers = {}

  add: (identifier, subscriber) ->
    @subscribers[identifier] = subscriber
    if @cable.sendCommand(identifier, "subscribe")
      @notify(identifier, "connected")

  reload: ->
    for identifier in Object.keys(@subscribers)
      if @cable.sendCommand(identifier, "subscribe")
        @notify(identifier, "connected")

  remove: (identifier) ->
    if subscriber = @subscribers[identifier]
      @cable.sendCommand(identifier, "unsubscribe")
      delete @subscribers[identifier]

  notifyAll: (event, args...) ->
    for identifier in Object.keys(@subscribers)
      @notify(identifier, event, args...)

  notify: (identifier, event, args...) ->
    if subscriber = @subscribers[identifier]
      subscriber[event]?(args...)
