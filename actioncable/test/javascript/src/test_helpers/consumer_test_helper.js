#= require mock-socket

{TestHelpers} = ActionCable

TestHelpers.consumerTest = (name, options = {}, callback) ->
  unless callback?
    callback = options
    options = {}

  options.url ?= TestHelpers.testURL

  QUnit.test name, (assert) ->
    doneAsync = assert.async()

    ActionCable.WebSocket = MockWebSocket
    server = new MockServer options.url
    consumer = ActionCable.createConsumer(options.url)

    server.on "connection", ->
      clients = server.clients()
      assert.equal clients.length, 1
      assert.equal clients[0].readyState, WebSocket.OPEN

    server.broadcastTo = (subscription, data = {}, callback) ->
      data.identifier = subscription.identifier

      if data.message_type
        data.type = ActionCable.INTERNAL.message_types[data.message_type]
        delete data.message_type

      server.send(JSON.stringify(data))
      TestHelpers.defer(callback)

    done = ->
      consumer.disconnect()
      server.close()
      doneAsync()

    testData = {assert, consumer, server, done}

    if options.connect is false
      callback(testData)
    else
      server.on "connection", ->
        testData.client = server.clients()[0]
        callback(testData)
      consumer.connect()
