# Collection class for creating (and internally managing) channel subscriptions. The only method intended to be triggered by the user
# us ActionCable.Subscriptions#create, and it should be called through the consumer like so:
#
#   @App = {}
#   App.cable = ActionCable.createConsumer "ws://example.com/accounts/1"
#   App.appearance = App.cable.subscriptions.create "AppearanceChannel"
#
# For more details on how you'd configure an actual channel subscription, see ActionCable.Subscription.
class ActionCable.Subscriptions
  constructor: (@consumer) ->
    @holdSubscriptions = []
    @subscriptions = []

  create: (channelName, mixin) ->
    channel = channelName
    params = if typeof channel is "object" then channel else {channel}
    subscription = new ActionCable.Subscription @consumer, params, mixin
    @add(subscription)
    subscription

  # Private

  add: (subscription) ->
    @holdSubscriptions.push(subscription)
    @consumer.ensureActiveConnection()
    # debugger
    @sendCommand(subscription, "subscribe")
    # subscription

  confirmSubscription: (identifier) ->
    for subscription in @findAllHold(identifier)
      @holdSubscriptions = @holdSubscriptions.filter (sub) -> sub isnt subscription
      @subscriptions.push(subscription)
      debugger

      # Create new subscription
      @notify(subscription, "initialized")

  remove: (subscription) ->
    @forget(subscription)
    unless @findAll(subscription.identifier).length
      @sendCommand(subscription, "unsubscribe")
    subscription

  reject: (identifier) ->
    for subscription in @findAll(identifier)
      @forget(subscription)
      @notify(subscription, "rejected")
      subscription

  forget: (subscription) ->
    @subscriptions = (s for s in @subscriptions when s isnt subscription)
    subscription

  findAll: (identifier) ->
    s for s in @subscriptions when s.identifier is identifier

  findAllHold: (identifier) ->
    s for s in @holdSubscriptions when s.identifier is identifier

  reload: ->
    for subscription in @subscriptions
      @sendCommand(subscription, "subscribe")

  notifyAll: (callbackName, args...) ->
    for subscription in @subscriptions
      @notify(subscription, callbackName, args...)

  notify: (subscription, callbackName, args...) ->
    if typeof subscription is "string"
      subscriptions = @findAll(subscription)
    else
      subscriptions = [subscription]

    for subscription in subscriptions
      subscription[callbackName]?(args...)

  sendCommand: (subscription, command) ->
    {identifier} = subscription
    @consumer.send({command, identifier})
