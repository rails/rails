import * as ActionCable from "../../../../app/javascript/action_cable/index"
import consumerTest from "../test_helpers/consumer_test_helper"
import {defer} from "../test_helpers/index"

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

    test("offers the protocol extensions after the main protocols", assert => {
      const FakeWebSocket = function(url, protocols) { this.protocols = protocols }
      ActionCable.adapters.WebSocket = FakeWebSocket
      const connection = new ActionCable.Connection({})
      connection.monitor = { start() {} }
      connection.open()
      assert.equal(connection.webSocket.protocols[0], "actioncable-v1-json")
      assert.equal(connection.webSocket.protocols.includes("actioncable-ext-pong"), true)
    })
  })

  module("ping", () => {
    consumerTest("responds with a pong echoing the message when the pong extension is enabled", ({server, assert, done}) => {
      server.on("message", (message) => {
        const data = JSON.parse(message)
        assert.equal(data.command, "pong")
        assert.equal(data.message, 1234567890)
        done()
      })

      server.send(JSON.stringify({type: "welcome", extensions: ["pong"]}))
      server.send(JSON.stringify({type: "ping", message: 1234567890}))
    })

    consumerTest("is ignored when the pong extension is not enabled", ({server, assert, done}) => {
      server.on("message", (message) => {
        assert.ok(false, `unexpected message sent by the client: ${message}`)
      })

      server.send(JSON.stringify({type: "welcome"}))
      server.send(JSON.stringify({type: "ping", message: 1234567890}))

      defer(() => {
        assert.ok(true)
        done()
      })
    })
  })
})
