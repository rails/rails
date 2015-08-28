# Responsible for ensuring the cable connection is in good health by validating the heartbeat pings sent from the server, and attempting
# revival reconnections if things go astray. Internal class, not intended for direct user manipulation.
class Cable.ConnectionMonitor
  identifier: Cable.PING_IDENTIFIER

  pollInterval:
    min: 2
    max: 30

  staleThreshold:
    startedAt: 4
    pingedAt: 8

  constructor: (@consumer) ->
    @consumer.subscriptions.add(this)
    @start()

  connected: ->
    @reset()
    @pingedAt = now()

  disconnected: ->
    if @reconnectAttempts is 0
      @reconnectAttempts += 1
      setTimeout =>
        @consumer.connection.open()
      , 200

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

  stop: ->
    @stoppedAt = now()
    document.removeEventListener("visibilitychange", @visibilityDidChange)

  poll: ->
    setTimeout =>
      unless @stoppedAt
        @reconnectIfStale()
        @poll()
    , @getInterval()

  getInterval: ->
    {min, max} = @pollInterval
    interval = 4 * Math.log(@reconnectAttempts + 1)
    clamp(interval, min, max) * 1000

  reconnectIfStale: ->
    if @connectionIsStale()
      @reconnectAttempts += 1
      @consumer.connection.reopen()

  connectionIsStale: ->
    if @pingedAt
      secondsSince(@pingedAt) > @staleThreshold.pingedAt
    else
      secondsSince(@startedAt) > @staleThreshold.startedAt

  visibilityDidChange: =>
    if document.visibilityState is "visible"
      setTimeout =>
        if @connectionIsStale() or not @consumer.connection.isOpen()
          @consumer.connection.reopen()
      , 200

  toJSON: ->
    interval = @getInterval()
    connectionIsStale = @connectionIsStale()
    {@startedAt, @stoppedAt, @pingedAt, @reconnectAttempts, connectionIsStale, interval}

  now = ->
    new Date().getTime()

  secondsSince = (time) ->
    (now() - time) / 1000

  clamp = (number, min, max) ->
    Math.max(min, Math.min(max, number))
