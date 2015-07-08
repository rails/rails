# Encapsulate the cable connection held by the consumer. This is an internal class not intended for direct user manipulation.
class Cable.Connection
  constructor: (@consumer) ->
    @open()

  send: (data) ->
    if @isOpen()
      @webSocket.send(JSON.stringify(data))
      true
    else
      false

  open: ->
    return if @isState("open", "connecting")
    @webSocket = new WebSocket(@consumer.url)
    @installEventHandlers()

  close: ->
    return if @isState("closed", "closing")
    @webSocket?.close()

  reopen: ->
    if @isOpen()
      @closeSilently => @open()
    else
      @open()

  isOpen: ->
    @isState("open")

  # Private

  isState: (states...) ->
    @getState() in states

  getState: ->
    return state.toLowerCase() for state, value of WebSocket when value is @webSocket?.readyState
    null

  closeSilently: (callback = ->) ->
    @uninstallEventHandlers()
    @installEventHandler("close", callback)
    @installEventHandler("error", callback)
    try
      @webSocket.close()
    finally
      @uninstallEventHandlers()

  installEventHandlers: ->
    for eventName of @events
      @installEventHandler(eventName)

  installEventHandler: (eventName, handler) ->
    handler ?= @events[eventName].bind(this)
    @webSocket.addEventListener(eventName, handler)

  uninstallEventHandlers: ->
    for eventName of @events
      @webSocket.removeEventListener(eventName)

  events:
    message: (event) ->
      {identifier, message} = JSON.parse(event.data)
      @consumer.subscriptions.notify(identifier, "received", message)

    open: ->
      @consumer.subscriptions.reload()

    close: ->
      @consumer.subscriptions.notifyAll("disconnected")

    error: ->
      @consumer.subscriptions.notifyAll("disconnected")
      @closeSilently()

  toJSON: ->
    state: @getState()
