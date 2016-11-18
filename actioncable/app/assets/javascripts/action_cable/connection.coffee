#= require ./connection_monitor

# Encapsulate the cable connection held by the consumer. This is an internal class not intended for direct user manipulation.

{message_types, protocols} = ActionCable.INTERNAL
[supportedProtocols..., unsupportedProtocol] = protocols

class ActionCable.Connection
  @reopenDelay: 500

  constructor: (@consumer) ->
    {@subscriptions} = @consumer
    @monitor = new ActionCable.ConnectionMonitor this
    @disconnected = true

  send: (data) ->
    if @isOpen()
      @webSocket.send(JSON.stringify(data))
      true
    else
      false

  open: =>
    if @isActive()
      ActionCable.log("Attempted to open WebSocket, but existing socket is #{@getState()}")
      throw new Error("Existing connection must be closed before opening")
    else
      ActionCable.log("Opening WebSocket, current state is #{@getState()}, subprotocols: #{protocols}")
      @uninstallEventHandlers() if @webSocket?
      @webSocket = new ActionCable.WebSocket(@consumer.url, protocols)
      @installEventHandlers()
      @monitor.start()
      true

  close: ({allowReconnect} = {allowReconnect: true}) ->
    @monitor.stop() unless allowReconnect
    @webSocket?.close() if @isActive()

  reopen: ->
    ActionCable.log("Reopening WebSocket, current state is #{@getState()}")
    if @isActive()
      try
        @close()
      catch error
        ActionCable.log("Failed to reopen WebSocket", error)
      finally
        ActionCable.log("Reopening WebSocket in #{@constructor.reopenDelay}ms")
        setTimeout(@open, @constructor.reopenDelay)
    else
      @open()

  getProtocol: ->
    @webSocket?.protocol

  isOpen: ->
    @isState("open")

  isActive: ->
    @isState("open", "connecting")

  # Private

  isProtocolSupported: ->
    @getProtocol() in supportedProtocols

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
      return unless @isProtocolSupported()
      {identifier, message, type} = JSON.parse(event.data)
      switch type
        when message_types.welcome
          @monitor.recordConnect()
          @subscriptions.reload()
        when message_types.ping
          @monitor.recordPing()
        when message_types.confirmation
          @subscriptions.notify(identifier, "connected")
        when message_types.rejection
          @subscriptions.reject(identifier)
        else
          @subscriptions.notify(identifier, "received", message)

    open: ->
      ActionCable.log("WebSocket onopen event, using '#{@getProtocol()}' subprotocol")
      @disconnected = false
      if not @isProtocolSupported()
        ActionCable.log("Protocol is unsupported. Stopping monitor and disconnecting.")
        @close(allowReconnect: false)

    close: (event) ->
      ActionCable.log("WebSocket onclose event")
      return if @disconnected
      @disconnected = true
      @monitor.recordDisconnect()
      @subscriptions.notifyAll("disconnected", {willAttemptReconnect: @monitor.isRunning()})

    error: ->
      ActionCable.log("WebSocket onerror event")
