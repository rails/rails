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
    if @isAlive()
      ActionCable.log("Attemped to open WebSocket, but existing socket is #{@getState()}")
      throw new Error("Existing connection must be closed before opening")
    else
      ActionCable.log("Opening WebSocket, current state is #{@getState()}")
      @uninstallEventHandlers() if @webSocket?
      @webSocket = new WebSocket(@consumer.url)
      @installEventHandlers()
      true

  close: ->
    @webSocket?.close()

  reopen: ->
    ActionCable.log("Reopening WebSocket, current state is #{@getState()}")
    if @isAlive()
      try
        @close()
      catch error
        ActionCable.log("Failed to reopen WebSocket", error)
      finally
        ActionCable.log("Reopening WebSocket in #{@constructor.reopenDelay}ms")
        setTimeout(@open, @constructor.reopenDelay)
    else
      @open()

  isOpen: ->
    @isState("open")

  # Private

  isAlive: ->
    @webSocket? and not @isState("closing", "closed")

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

  uninstallEventHandlers: ->
    for eventName of @events
      @webSocket["on#{eventName}"] = ->
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
      ActionCable.log("WebSocket onopen event")
      @disconnected = false
      @consumer.subscriptions.reload()

    close: ->
      ActionCable.log("WebSocket onclose event")
      @disconnect()

    error: ->
      ActionCable.log("WebSocket onerror event")
      @disconnect()

  disconnect: ->
    return if @disconnected
    @disconnected = true
    @consumer.subscriptions.notifyAll("disconnected")
