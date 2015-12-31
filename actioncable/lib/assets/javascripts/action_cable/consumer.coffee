#= require action_cable/connection
#= require action_cable/connection_monitor
#= require action_cable/subscriptions
#= require action_cable/subscription

# The ActionCable.Consumer establishes the connection to a server-side Ruby Connection object. Once established,
# the ActionCable.ConnectionMonitor will ensure that its properly maintained through heartbeats and checking for stale updates.
# The Consumer instance is also the gateway to establishing subscriptions to desired channels through the #createSubscription
# method.
#
# The following example shows how this can be setup:
#
#   @App = {}
#   App.cable = ActionCable.createConsumer "ws://example.com/accounts/1"
#   App.appearance = App.cable.subscriptions.create "AppearanceChannel"
#
# For more details on how you'd configure an actual channel subscription, see ActionCable.Subscription.
class ActionCable.Consumer
  constructor: (@url) ->
    @subscriptions = new ActionCable.Subscriptions this
    @connection = new ActionCable.Connection this
    @connectionMonitor = new ActionCable.ConnectionMonitor this

  send: (data) ->
    @connection.send(data)
