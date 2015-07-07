class Cable.Connection
  constructor: (@consumer) ->
    @open()

  send: (data) ->
    if @isOpen()
      @webSocket.send(JSON.stringify(data))
      true
    else
      false

  open: =>
    return if @isState("open", "connecting")
    @webSocket = new WebSocket(@consumer.url)
    @webSocket.onmessage = @onMessage
    @webSocket.onopen    = @onOpen
    @webSocket.onclose   = @onClose
    @webSocket.onerror   = @onError

  close: ->
    return if @isState("closed", "closing")
    @webSocket?.close()

  reopen: ->
    if @isOpen()
      @webSocket.onclose = @open
      @webSocket.onerror = @open
      @webSocket.close()
    else
      @open()

  isOpen: ->
    @isState("open")

  isState: (states...) ->
    @getState() in states

  getState: ->
    return state.toLowerCase() for state, value of WebSocket when value is @webSocket?.readyState
    null

  onMessage: (message) =>
    data = JSON.parse message.data
    @consumer.subscribers.notify(data.identifier, "received", data.message)

  onOpen: =>
    @consumer.subscribers.reload()

  onClose: =>
    @disconnect()

  onError: =>
    @disconnect()
    @webSocket.onclose = -> # no-op
    @webSocket.onerror = -> # no-op
    try @close()

  disconnect: ->
    @consumer.subscribers.notifyAll("disconnected")
