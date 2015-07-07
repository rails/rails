class Cable.Connection
  constructor: (@consumer) ->
    @open()

  send: (data) ->
    if @isOpen()
      @websocket.send(JSON.stringify(data))
      true
    else
      false

  open: =>
    return if @isState("open", "connecting")
    @websocket = new WebSocket(@consumer.url)
    @websocket.onmessage = @onMessage
    @websocket.onopen    = @onOpen
    @websocket.onclose   = @onClose
    @websocket.onerror   = @onError

  close: ->
    return if @isState("closed", "closing")
    @websocket?.close()

  reopen: ->
    if @isOpen()
      @websocket.onclose = @open
      @websocket.onerror = @open
      @websocket.close()
    else
      @open()

  isOpen: ->
    @isState("open")

  isState: (states...) ->
    @getState() in states

  getState: ->
    return state.toLowerCase() for state, value of WebSocket when value is @websocket?.readyState
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
    @websocket.onclose = -> # no-op
    @websocket.onerror = -> # no-op
    try @close()

  disconnect: ->
    @consumer.subscribers.notifyAll("disconnected")
