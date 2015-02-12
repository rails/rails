class @Cable.Channel
  constructor: (params = {}) ->
    @channelName ?= @underscore @constructor.name

    params['channel'] = @channelName
    @channelIdentifier = JSON.stringify params

    cable.subscribe(@channelIdentifier, {
      onConnect: @connected
      onDisconnect: @disconnected
      onReceiveData: @received
    })

  connected: =>
    # Override in the subclass

  disconnected: =>
    # Override in the subclass

  received: (data) =>
    # Override in the subclass

  send: (data) ->
    cable.sendData @channelIdentifier, JSON.stringify data

  underscore: (value) ->
    value.replace(/[A-Z]/g, (match) => "_#{match.toLowerCase()}").substr(1)