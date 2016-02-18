# Encapsulate the cable connection held by the consumer. This is an internal class not intended for direct user manipulation.

{message_types} = ActionCable.INTERNAL

class ActionCable.Connection
  @reopenDelay: 500

  constructor: (@consumer) ->
    @open()

  send: (data) ->
    if @isOpen()
      @webSocket.send(JSON.stringify(data))
      true
    else
      false

  open: =>
    if @webSocket and not @isClosed()
      console.log("[cable] Attemped to open WebSocket, but existing socket is #{@getState()}", Date.now())
      throw new Error("Existing connection must be closed before opening")
    else
      console.log("[cable] Opening WebSocket, current state is #{@getState()}", Date.now())
      @webSocket = new WebSocket(@consumer.url)
      @installEventHandlers()
      true

  close: ->
    @webSocket?.close()

  reopen: ->
    console.log("[cable] Reopening WebSocket, current state is #{@getState()}", Date.now())
    if @isClosed()
      @open()
    else
      try
        @close()
      finally
        console.log("[cable] Failed to reopen WebSocket, retrying in #{@constructor.reopenDelay}ms", Date.now())
        setTimeout(@open, @constructor.reopenDelay)

  isOpen: ->
    @isState("open")

  # Private

  isClosed: ->
    @isState("closing", "closed")

  isState: (states...) ->
    @getState() in states

  getState: ->
    return state.toLowerCase() for state, value of WebSocket when value is @webSocket?.readyState
    null

  installEventHandlers: ->
    for eventName of @events
      handler = @events[eventName].bind(this)
      @webSocket["on#{eventName}"] = handler
    return

  events:
    message: (event) ->
      {identifier, message, type} = JSON.parse(event.data)

      switch type
        when message_types.confirmation
          @consumer.subscriptions.notify(identifier, "connected")
        when message_types.rejection
          @consumer.subscriptions.reject(identifier)
        else
          @consumer.subscriptions.notify(identifier, "received", message)

    open: ->
      console.log("[cable] WebSocket onopen event", Date.now())
      @disconnected = false
      @consumer.subscriptions.reload()

    close: ->
      console.log("[cable] WebSocket onclose event", Date.now())
      @disconnect()

    error: ->
      console.log("[cable] WebSocket onerror event", Date.now())
      @disconnect()

  disconnect: ->
    return if @disconnected
    @disconnected = true
    @consumer.subscriptions.notifyAll("disconnected")
