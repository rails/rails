class Cable.ConnectionMonitor
  MAX_CONNECTION_INTERVAL: 5 * 1000
  PING_STALE_INTERVAL: 8 * 1000

  identifier: Cable.PING_IDENTIFIER

  constructor: (@consumer) ->
    @reset()
    @consumer.subscribers.add(this)
    @pollConnection()

  connected: ->
    @reset()
    @pingedAt = now()

  received: ->
    @pingedAt = now()

  reset: ->
    @connectionAttempts = 1

  pollConnection: ->
    setTimeout =>
      @reconnect() if @connectionIsStale()
      @pollConnection()
    , @getPollTimeout()

  getPollTimeout: ->
    interval = (Math.pow(2, @connectionAttempts) - 1) * 1000
    if interval > @MAX_CONNECTION_INTERVAL then @MAX_CONNECTION_INTERVAL else interval

  connectionIsStale: ->
    @pingedAt? and (now() - @pingedAt) > @PING_STALE_INTERVAL

  reconnect: ->
    console.log "Ping took too long to arrive. Reconnecting.."
    @connectionAttempts += 1
    @consumer.connection.reopen()

  now = ->
    new Date().getTime()
