#= require cable/connection_monitor

class Cable.Connection
  constructor: (@consumer) ->
    new Cable.ConnectionMonitor @consumer
    @connect()

  send: (data) ->
    if @isConnected()
      @websocket.send(JSON.stringify(data))
      true
    else
      false

  connect: ->
    @removeWebsocket()
    @createWebSocket()

  createWebSocket: ->
    @websocket = new WebSocket(@consumer.url)
    @websocket.onmessage = @onMessage
    @websocket.onopen    = @onConnect
    @websocket.onclose   = @onClose
    @websocket.onerror   = @onError
    @websocket

  removeWebsocket: ->
    if @websocket?
      @websocket.onclose = -> # no-op
      @websocket.onerror = -> # no-op
      @websocket.close()
      @websocket = null

  onMessage: (message) =>
    data = JSON.parse message.data
    @consumer.subscribers.notify(data.identifier, "received", data.message)

  onConnect: =>
    @consumer.subscribers.reload()

  onClose: =>
    @disconnect()

  onError: =>
    @disconnect()

  isConnected: ->
    @websocket?.readyState is 1

  disconnect: ->
    @consumer.subscribers.notifyAll("disconnected")
    @removeWebsocket()
