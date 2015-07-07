class Cable.ConnectionMonitor
  identifier: Cable.PING_IDENTIFIER

  pollInterval:
    min: 2
    max: 30

  staleThreshold:
    startedAt: 4
    pingedAt: 8

  constructor: (@consumer) ->
    @consumer.subscribers.add(this)
    @start()

  connected: ->
    @reset()
    @pingedAt = now()

  received: ->
    @pingedAt = now()

  reset: ->
    @reconnectAttempts = 0

  start: ->
    @reset()
    delete @stoppedAt
    @startedAt = now()
    @poll()

  stop: ->
    @stoppedAt = now()

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
