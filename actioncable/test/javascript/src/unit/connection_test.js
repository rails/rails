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
})
