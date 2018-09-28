import {ActionCable} from "../test_helpers/index.js"

const {module, test} = QUnit
const {consumerTest} = ActionCable.TestHelpers

module("ActionCable.Subscriptions", function() {
  consumerTest("create subscription with channel string", function({consumer, server, assert, done}) {
    const channel = "chat"

    server.on("message", function(message) {
      const data = JSON.parse(message)
      assert.equal(data.command, "subscribe")
      assert.equal(data.identifier, JSON.stringify({channel}))
      return done()
    })

    return consumer.subscriptions.create(channel)
  })

  return consumerTest("create subscription with channel object", function({consumer, server, assert, done}) {
    const channel = {channel: "chat", room: "action"}

    server.on("message", function(message) {
      const data = JSON.parse(message)
      assert.equal(data.command, "subscribe")
      assert.equal(data.identifier, JSON.stringify(channel))
      return done()
    })

    return consumer.subscriptions.create(channel)
  })
})
