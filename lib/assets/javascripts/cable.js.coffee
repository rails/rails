#= require_self
#= require cable/subscriber_manager
#= require cable/connection
#= require cable/channel

class @Cable
  @PING_IDENTIFIER: "_ping"

  constructor: (@url) ->
    @subscribers = new Cable.SubscriberManager this
    @connection = new Cable.Connection this

  createChannel: (channelName, mixin) ->
    channel = channelName
    params = if typeof channel is "object" then channel else {channel}
    new Cable.Channel this, params, mixin

  send: (data) ->
    @connection.send(data)
