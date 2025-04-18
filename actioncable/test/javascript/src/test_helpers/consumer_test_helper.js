import { WebSocket as MockWebSocket, Server as MockServer } from "mock-socket"
import * as ActionCable from "../../../../app/javascript/action_cable/index"
import {defer, testURL} from "./index"

export default function(name, options, callback) {
  if (options == null) { options = {} }
  if (callback == null) {
    callback = options
    options = {}
  }

  if (options.url == null) { options.url = testURL }

  return QUnit.test(name, function(assert) {
    const doneAsync = assert.async()

    ActionCable.adapters.WebSocket = MockWebSocket
    const server = new MockServer(options.url)
    const consumer = ActionCable.createConsumer(options.url)
    const connection = consumer.connection
    const monitor = connection.monitor

    if ("subprotocols" in options) consumer.addSubProtocol(options.subprotocols)

    server.on("connection", function() {
      const clients = server.clients()
      assert.equal(clients.length, 1)
      assert.equal(clients[0].readyState, WebSocket.OPEN)
    })

    server.broadcastTo = function(subscription, data, callback) {
      if (data == null) { data = {} }
      data.identifier = subscription.identifier

      if (data.message_type) {
        data.type = ActionCable.INTERNAL.message_types[data.message_type]
        delete data.message_type
      }

      server.send(JSON.stringify(data))
      defer(callback)
    }

    const done = function() {
      consumer.disconnect()
      server.close()
      doneAsync()
    }

    const testData = {assert, consumer, connection, monitor, server, done}

    if (options.connect === false) {
      callback(testData)
    } else {
      server.on("connection", function() {
        testData.client = server.clients()[0]
        callback(testData)
      })
      consumer.connect()
    }
  })
}
