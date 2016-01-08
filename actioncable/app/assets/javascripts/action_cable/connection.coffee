# Encapsulate the cable connection held by the consumer. This is an internal class not intended for direct user manipulation.

{message_types} = ActionCable.INTERNAL

class ActionCable.Connection
  @reopenDelay: 500

  constructor: (@consumer) ->

  send: (data) ->
    unless @isOpen()
      @open()

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
          notification_type = "connected"
          @consumer.subscriptions.notify(identifier, notification_type)
          @events.dispatchEvent(identifier, notification_type)
        when message_types.rejection
          @consumer.subscriptions.reject(identifier)
        else
          notification_type = "received"
          @consumer.subscriptions.notify(identifier, notification_type, message)
          @events.dispatchEvent(identifier, notification_type, message)

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

    dispatchEvent: (identifier, type, message) ->
      unless identifier == "_ping"
        event = document.createEvent('Event')
        event.initEvent("cable:#{type}", true, false)
        channel = JSON.parse(identifier).channel
        event.cable = {data: message, identifier: channel}
        document.dispatchEvent(event)

  disconnect: ->
    return if @disconnected
    @disconnected = true
    notification_type = "disconnected"
    @consumer.subscriptions.notifyAll(notification_type)
    @events.dispatchEvent("{\"channel\": \"All\"}", notification_type)
