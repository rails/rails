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
    @websocket = new WebSocket(@consumer.url)
    @websocket.onmessage = @onMessage
    @websocket.onopen    = @onOpen
    @websocket.onclose   = @onClose
    @websocket.onerror   = @onError

  close: ->
    @websocket.close() unless @isClosed()

  reopen: ->
    if @isClosed()
      @open()
    else
      @websocket.onclose = @open
      @websocket.onerror = @open
      @websocket.close()

  isOpen: ->
    @websocket.readyState is WebSocket.OPEN

  isClosed: ->
    @websocket.readyState in [ WebSocket.CLOSED, WebSocket.CLOSING ]

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
