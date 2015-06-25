#= require_self
#= require cable/subscriber_manager
#= require cable/connection
#= require cable/channel

class @Cable
  constructor: (@url) ->
    @subscribers = new Cable.SubscriberManager this
    @connection = new Cable.Connection this

  createChannel: (channelName, mixin) ->
    channel = channelName
    params = if typeof channel is "object" then channel else {channel}
    new Cable.Channel this, params, mixin

  sendMessage: (identifier, data) ->
    @sendCommand(identifier, "message", data)

  sendCommand: (identifier, command, data) ->
    @connection.send({identifier, command, data})
