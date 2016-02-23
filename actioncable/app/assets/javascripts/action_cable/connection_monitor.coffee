# Responsible for ensuring the cable connection is in good health by validating the heartbeat pings sent from the server, and attempting
# revival reconnections if things go astray. Internal class, not intended for direct user manipulation.
class ActionCable.ConnectionMonitor
  @pollInterval:
    min: 3
    max: 30

  @staleThreshold: 6 # Server::Connections::BEAT_INTERVAL * 2 (missed two pings)

  identifier: ActionCable.INTERNAL.identifiers.ping

  constructor: (@consumer) ->
    @consumer.subscriptions.add(this)
    @start()

  connected: ->
    @reset()
    @pingedAt = now()
    delete @disconnectedAt
    ActionCable.log("ConnectionMonitor connected")

  disconnected: ->
    @disconnectedAt = now()

  received: ->
    @pingedAt = now()

  reset: ->
    @reconnectAttempts = 0

  start: ->
    @reset()
    delete @stoppedAt
    @startedAt = now()
    @poll()
    document.addEventListener("visibilitychange", @visibilityDidChange)
    ActionCable.log("ConnectionMonitor started, pollInterval is #{@getInterval()}ms")

  stop: ->
    @stoppedAt = now()
    document.removeEventListener("visibilitychange", @visibilityDidChange)
    ActionCable.log("ConnectionMonitor stopped")

  poll: ->
    setTimeout =>
      unless @stoppedAt
        @reconnectIfStale()
        @poll()
    , @getInterval()

  getInterval: ->
    {min, max} = @constructor.pollInterval
    interval = 5 * Math.log(@reconnectAttempts + 1)
    clamp(interval, min, max) * 1000

  reconnectIfStale: ->
    if @connectionIsStale()
      ActionCable.log("ConnectionMonitor detected stale connection, reconnectAttempts = #{@reconnectAttempts}")
      @reconnectAttempts++
      if @disconnectedRecently()
        ActionCable.log("ConnectionMonitor skipping reopen because recently disconnected at #{@disconnectedAt}")
      else
        ActionCable.log("ConnectionMonitor reopening")
        @consumer.connection.reopen()

  connectionIsStale: ->
    secondsSince(@pingedAt ? @startedAt) > @constructor.staleThreshold

  disconnectedRecently: ->
    @disconnectedAt and secondsSince(@disconnectedAt) < @constructor.staleThreshold

  visibilityDidChange: =>
    if document.visibilityState is "visible"
      setTimeout =>
        if @connectionIsStale() or not @consumer.connection.isOpen()
          ActionCable.log("ConnectionMonitor reopening stale connection after visibilitychange to #{document.visibilityState}")
          @consumer.connection.reopen()
      , 200

  now = ->
    new Date().getTime()

  secondsSince = (time) ->
    (now() - time) / 1000

  clamp = (number, min, max) ->
    Math.max(min, Math.min(max, number))
