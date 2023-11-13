import * as ActionCable from "../../../../app/javascript/action_cable/index"

const {module, test} = QUnit

module("ActionCable.Connection", () => {
  module("#getState", () => {
    test("uses the configured WebSocket adapter", assert => {
      ActionCable.adapters.WebSocket = { foo: 1, BAR: "42" }
      const connection = new ActionCable.Connection({})
      connection.webSocket = {}
      connection.webSocket.readyState = 1
      assert.equal(connection.getState(), "foo")
      connection.webSocket.readyState = "42"
      assert.equal(connection.getState(), "bar")
    })
  })

  module("#open", () => {
    test("uses the configured WebSocket adapter", assert => {
      const FakeWebSocket = function() {}
      ActionCable.adapters.WebSocket = FakeWebSocket
      const connection = new ActionCable.Connection({})
      connection.monitor = { start() {} }
      connection.open()
      assert.equal(connection.webSocket instanceof FakeWebSocket, true)
    })
  })

  module("#isExpectedToRespondwithPongToPing", () => {
    test("returns true for actioncable-v1.1-* protocols", assert => {
      const connection = new ActionCable.Connection({})
      connection.webSocket = { protocol: "actioncable-v1.1-foo" }
      assert.equal(connection.isExpectedToRespondwithPongToPing(), true)

      connection.webSocket = { protocol: "actioncable-v1-json" }
      assert.equal(connection.isExpectedToRespondwithPongToPing(), false)
    })
  })

  module("#events", () => {
    test("#message responds to a PING message with a PONG, if expected to do so", assert => {
      const connection = new ActionCable.Connection({})

      const sentMessages = []
      connection.send = (payload) => sentMessages.push(payload)
      connection.isProtocolSupported = () => true

      const messageHandler = connection.events.message.bind(connection)

      connection.getProtocol = () => "actioncable-v1.1-json"
      messageHandler({ data: "{\"type\":\"ping\",\"message\":123.456}" })

      assert.equal(sentMessages.length, 1)
      assert.deepEqual(sentMessages[0], {type: "pong", message: 123.456})

      connection.getProtocol = () => "actioncable-v1-json"
      messageHandler({ data: "{\"type\":\"ping\",\"message\":123.456}" })

      assert.equal(sentMessages.length, 1)
    })
  })
})
