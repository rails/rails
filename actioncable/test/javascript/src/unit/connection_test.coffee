{module, test} = QUnit
{consumerTest} = ActionCable.TestHelpers

module "ActionCable.Connection", ->
  module '#open', (hooks) ->
    badConnection = undefined
    goodConnection = undefined
    sandbox = undefined

    hooks.beforeEach ->
      sandbox = sinon.sandbox.create()
      sandbox.spy(window.console, "log")
      sandbox.stub(Date, "now").withArgs().returns(123)

      badConnection = new ActionCable.Connection(ActionCable.createConsumer())
      sandbox.stub(badConnection, "isActive").withArgs().returns(true)
      sandbox.stub(badConnection, "getState").withArgs().returns("offline")

      goodConnection = new ActionCable.Connection(ActionCable.createConsumer())
      sandbox.stub(goodConnection, "isActive").withArgs().returns(false)
      return

    hooks.afterEach ->
      sandbox.restore()
      return

    module 'invalid', (hooks) ->
      test 'errors if already has a WebSocket connection', (assert) ->
        ActionCable.startDebugging()
        assert.throws (->
          badConnection.open()
          return
        ), Error, 'Existing connection must be closed before opening'

        assert.equal 1, console.log.callCount
        assert.deepEqual ["[ActionCable]", "Attempted to open WebSocket, but existing socket is offline", 123], console.log.getCall(0).args

    module '#valid', (hooks) ->
      hooks.afterEach ->
        if goodConnection.isActive()
          goodConnection.close()

      test 'logs', (assert) ->
        ActionCable.startDebugging()
        goodConnection.open()

        assert.equal 2, console.log.callCount
        assert.deepEqual ["[ActionCable]", "Opening WebSocket, current state is null, subprotocols: actioncable-v1-json,actioncable-unsupported", 123], console.log.getCall(0).args
        assert.deepEqual ["[ActionCable]", "ConnectionMonitor started. pollInterval = 3000 ms", 123], console.log.getCall(1).args

      test 'properly opens up socket', (assert) ->
        goodConnection.open()

        assert.equal WebSocket.CONNECTING, goodConnection.webSocket.readyState
        assert.equal "WebSocket", goodConnection.webSocket.constructor.name

      test 'installs event handlers', (assert) ->
        goodConnection.events = testEvent: ->
        goodConnection.open()

        allMethods = Object.getOwnPropertyNames(goodConnection.webSocket)
        assert.deepEqual ["ontestEvent"], allMethods

      test 'starts ConnectionMonitor', (assert) ->
        goodConnection.open()

        assert.equal true, goodConnection.monitor.isRunning()

      test 'returns true', (assert) ->
        assert.equal true, goodConnection.open()

  module '#reopenDelay', ->
    test 'defaults to 500', (assert) ->
      assert.equal 500, ActionCable.Connection.reopenDelay

  module '#send', (hooks) ->
    consumerTest "returns true if data is sent", connect: false, ({assert, consumer, server, done}) ->
      consumer.connect()
      connection = new ActionCable.Connection(consumer)
      connection.open()
      assert.equal true, connection.send({ hi: 'hi' })

    test 'returns false if connection is not open', (assert) ->
      connection = new ActionCable.Connection(ActionCable.createConsumer())
      assert.equal false, connection.send({})
