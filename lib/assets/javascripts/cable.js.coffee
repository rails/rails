#= require_self
#= require_tree .

class @Cable
  MAX_CONNECTION_ATTEMPTS: 10
  MAX_CONNECTION_INTERVAL: 5 * 1000
  MAX_PING_INTERVAL: 6

  constructor: (@cableUrl) ->
    @subscribers = {}
    @resetPingTime()
    @resetConnectionAttemptsCount()
    @connect()

  connect: ->
    @connection = @createConnection()

  createConnection: ->
    connection = new WebSocket(@cableUrl)
    connection.onmessage = @receiveData
    connection.onopen    = @connected
    connection.onclose   = @reconnect

    connection.onerror   = @reconnect
    connection

  isConnected: =>
    @connection?.readyState is 1

  sendData: (identifier, data) =>
    if @isConnected()
      @connection.send JSON.stringify { action: 'message', identifier: identifier, data: data }

  receiveData: (message) =>
    data = JSON.parse message.data

    if data.identifier is '_ping'
      @pingReceived(data.message)
    else
      @subscribers[data.identifier]?.onReceiveData(data.message)

  connected: =>
    @resetConnectionAttemptsCount()

    for identifier, callbacks of @subscribers
      @subscribeOnServer(identifier)
      callbacks['onConnect']?()

  reconnect: =>
    @resetPingTime()
    @disconnected()

    setTimeout =>
      if @isMaxConnectionAttemptsReached()
        @giveUp()
      else
        @incrementConnectionAttemptsCount()
        @connect()
    , @generateReconnectInterval()

  resetConnectionAttemptsCount: =>
    @connectionAttempts = 1

  incrementConnectionAttemptsCount: =>
    @connectionAttempts += 1

  isMaxConnectionAttemptsReached: =>
    @connectionAttempts > @MAX_CONNECTION_ATTEMPTS

  generateReconnectInterval: () ->
    interval = (Math.pow(2, @connectionAttempts) - 1) * 1000
    if interval > @MAX_CONNECTION_INTERVAL then @MAX_CONNECTION_INTERVAL else interval

  resetPingTime: () =>
    @lastPingTime = null

  disconnected: =>
    callbacks['onDisconnect']?() for identifier, callbacks of @subscribers

  giveUp: =>
    # Show an error message

  subscribe: (identifier, callbacks) =>
    @subscribers[identifier] = callbacks

    if @isConnected()
      @subscribeOnServer(identifier)
      @subscribers[identifier]['onConnect']?()

  unsubscribe: (identifier) =>
    @unsubscribeOnServer(identifier, 'unsubscribe')
    delete @subscribers[identifier]

  subscribeOnServer: (identifier) =>
    if @isConnected()
      @connection.send JSON.stringify { action: 'subscribe', identifier: identifier }

  unsubscribeOnServer: (identifier) =>
    if @isConnected()
      @connection.send JSON.stringify { action: 'unsubscribe', identifier: identifier }

  pingReceived: (timestamp) =>
    if @lastPingTime? and (timestamp - @lastPingTime) > @MAX_PING_INTERVAL
      console.log "Websocket connection is stale. Reconnecting.."
      @connection.close()
    else
      @lastPingTime = timestamp
