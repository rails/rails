#= require cable/connection
#= require cable/connection_monitor
#= require cable/subscriptions
#= require cable/subscription

# The Cable.Consumer establishes the connection to a server-side Ruby Connection object. Once established,
# the Cable.ConnectionMonitor will ensure that its properly maintained through heartbeats and checking for stale updates.
# The Consumer instance is also the gateway to establishing subscriptions to desired channels through the #createSubscription
# method.
#
# The following example shows how this can be setup:
#
#   @App = {}
#   App.cable = Cable.createConsumer "ws://example.com/accounts/1"
#   App.appearance = App.cable.subscriptions.create "AppearanceChannel"
#
# For more details on how you'd configure an actual channel subscription, see Cable.Subscription.
class Cable.Consumer
  constructor: (@url) ->
    @subscriptions = new Cable.Subscriptions this
    @connection = new Cable.Connection this
    @connectionMonitor = new Cable.ConnectionMonitor this

  send: (data) ->
    @connection.send(data)

  inspect: ->
    JSON.stringify(this, null, 2)

  toJSON: ->
    {@url, @subscriptions, @connection, @connectionMonitor}
