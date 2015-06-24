#= require_self
#= require_tree .

class @Cable
  MAX_CONNECTION_INTERVAL: 5 * 1000
  PING_STALE_INTERVAL: 8

  constructor: (@cableUrl) ->
    @subscribers = {}
    @resetPingTime()
    @resetConnectionAttemptsCount()
    @connect()

  connect: ->
    @connection = @createConnection()

  createConnection: ->
    connection = new WebSocket(@cableUrl)
    connection.onmessage = @onMessage
    connection.onopen    = @onConnect
    connection.onclose   = @onClose
    connection.onerror   = @onError
    connection

  createChannel: (channelName, mixin) ->
    channel = channelName
    params = if typeof channel is "object" then channel else {channel}
    new Cable.Channel this, params, mixin

  isConnected: =>
    @connection?.readyState is 1

  sendMessage: (identifier, data) =>
    if @isConnected()
      @connection.send JSON.stringify { command: 'message', identifier: identifier, data: data }

  onMessage: (message) =>
    data = JSON.parse message.data

    if data.identifier is '_ping'
      @pingReceived(data.message)
    else
      @subscribers[data.identifier]?.onMessage?(data.message)

  onConnect: =>
    @startWaitingForPing()
    @resetConnectionAttemptsCount()

    for identifier, subscriber of @subscribers
      @subscribeOnServer(identifier)
      subscriber.onConnect?()

  onClose: =>
    @reconnect()

  onError: =>
    @reconnect()

  disconnect: ->
    @removeExistingConnection()
    @resetPingTime()
    for identifier, subscriber of @subscribers
      subscriber.onDisconnect?()

  reconnect: ->
    @disconnect()

    setTimeout =>
      @incrementConnectionAttemptsCount()
      @connect()
    , @generateReconnectInterval()

  removeExistingConnection: =>
    if @connection?
      @clearPingWaitTimeout()

      @connection.onclose = -> # no-op
      @connection.onerror = -> # no-op
      @connection.close()
      @connection = null

  resetConnectionAttemptsCount: =>
    @connectionAttempts = 1

  incrementConnectionAttemptsCount: =>
    @connectionAttempts += 1

  generateReconnectInterval: () ->
    interval = (Math.pow(2, @connectionAttempts) - 1) * 1000
    if interval > @MAX_CONNECTION_INTERVAL then @MAX_CONNECTION_INTERVAL else interval

  startWaitingForPing: =>
    @clearPingWaitTimeout()

    @waitForPingTimeout = setTimeout =>
      console.log "Ping took too long to arrive. Reconnecting.."
      @reconnect()
    , @PING_STALE_INTERVAL * 1000

  clearPingWaitTimeout: =>
    clearTimeout(@waitForPingTimeout)

  resetPingTime: =>
    @lastPingTime = null

  giveUp: =>
    # Show an error message

  subscribe: (identifier, subscriber) =>
    @subscribers[identifier] = subscriber

    if @isConnected()
      @subscribeOnServer(identifier)
      subscriber.onConnect?()

  unsubscribe: (identifier) =>
    @unsubscribeOnServer(identifier)
    delete @subscribers[identifier]

  subscribeOnServer: (identifier) =>
    if @isConnected()
      @connection.send JSON.stringify { command: 'subscribe', identifier: identifier }

  unsubscribeOnServer: (identifier) =>
    if @isConnected()
      @connection.send JSON.stringify { command: 'unsubscribe', identifier: identifier }

  pingReceived: (timestamp) =>
    if @lastPingTime? and (timestamp - @lastPingTime) > @PING_STALE_INTERVAL
      console.log "Websocket connection is stale. Reconnecting.."
      @reconnect()
    else
      @startWaitingForPing()
      @lastPingTime = timestamp
