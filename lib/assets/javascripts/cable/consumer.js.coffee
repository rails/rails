#= require cable/connection
#= require cable/subscription
#= require cable/subscriber_manager

class Cable.Consumer
  constructor: (@url) ->
    @subscribers = new Cable.SubscriberManager this
    @connection = new Cable.Connection this

  createSubscription: (channelName, mixin) ->
    channel = channelName
    params = if typeof channel is "object" then channel else {channel}
    new Cable.Subscription this, params, mixin

  send: (data) ->
    @connection.send(data)
