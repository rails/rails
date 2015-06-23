class @Cable.Channel
  constructor: (params = {}) ->
    {channelName} = @constructor

    if channelName?
      params['channel'] = channelName
      @channelIdentifier = JSON.stringify params
    else
      throw new Error "This channel's constructor is missing the required 'channelName' property"

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

  # Perform a channel action with the optional data passed as an attribute
  perform: (action, data = {}) ->
    data.action = action
    cable.sendData @channelIdentifier, JSON.stringify data

  send: (data) ->
    cable.sendData @channelIdentifier, JSON.stringify data
