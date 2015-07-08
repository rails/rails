# Collection class for creating (and internally managing) channel subscriptions. The only method intended to be triggered by the user
# us Cable.Subscriptions#create, and it should be called through the consumer like so:
#
#   @App = {}
#   App.cable = Cable.createConsumer "http://example.com/accounts/1"
#   App.appearance = App.cable.subscriptions.create "AppearanceChannel"
#
# For more details on how you'd configure an actual channel subscription, see Cable.Subscription.
class Cable.Subscriptions
  constructor: (@consumer) ->
    @subscriptions = []

  create: (channelName, mixin) ->
    channel = channelName
    params = if typeof channel is "object" then channel else {channel}
    new Cable.Subscription this, params, mixin

  # Private

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
