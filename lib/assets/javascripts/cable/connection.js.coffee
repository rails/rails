class Cable.Connection
  MAX_CONNECTION_INTERVAL: 5 * 1000
  PING_STALE_INTERVAL: 8

  constructor: (@cable) ->
    @resetPingTime()
    @resetConnectionAttemptsCount()
    @connect()

  send: (data) ->
    if @isConnected()
      @websocket.send(JSON.stringify(data))
      true
    else
      false

  connect: ->
    @websocket = @createWebSocket()

  createWebSocket: ->
    ws = new WebSocket(@cable.url)
    ws.onmessage = @onMessage
    ws.onopen    = @onConnect
    ws.onclose   = @onClose
    ws.onerror   = @onError
    ws

  onMessage: (message) =>
    data = JSON.parse message.data

    if data.identifier is '_ping'
      @pingReceived(data.message)
    else
      @cable.subscribers.notify(data.identifier, "received", data.message)

  onConnect: =>
    @startWaitingForPing()
    @resetConnectionAttemptsCount()
    @cable.subscribers.reload()

  onClose: =>
    @reconnect()

  onError: =>
    @reconnect()

  isConnected: ->
    @websocket?.readyState is 1

  disconnect: ->
    @removeExistingConnection()
    @resetPingTime()
    @cable.subscribers.notifyAll("disconnected")

  reconnect: ->
    @disconnect()

    setTimeout =>
      @incrementConnectionAttemptsCount()
      @connect()
    , @generateReconnectInterval()

  removeExistingConnection: ->
    if @websocket?
      @clearPingWaitTimeout()

      @websocket.onclose = -> # no-op
      @websocket.onerror = -> # no-op
      @websocket.close()
      @websocket = null

  resetConnectionAttemptsCount: ->
    @connectionAttempts = 1

  incrementConnectionAttemptsCount: ->
    @connectionAttempts += 1

  generateReconnectInterval: () ->
    interval = (Math.pow(2, @connectionAttempts) - 1) * 1000
    if interval > @MAX_CONNECTION_INTERVAL then @MAX_CONNECTION_INTERVAL else interval

  startWaitingForPing: ->
    @clearPingWaitTimeout()

    @waitForPingTimeout = setTimeout =>
      console.log "Ping took too long to arrive. Reconnecting.."
      @reconnect()
    , @PING_STALE_INTERVAL * 1000

  clearPingWaitTimeout: ->
    clearTimeout(@waitForPingTimeout)

  resetPingTime: ->
    @lastPingTime = null

  pingReceived: (timestamp) ->
    if @lastPingTime? and (timestamp - @lastPingTime) > @PING_STALE_INTERVAL
      console.log "Websocket connection is stale. Reconnecting.."
      @reconnect()
    else
      @startWaitingForPing()
      @lastPingTime = timestamp
