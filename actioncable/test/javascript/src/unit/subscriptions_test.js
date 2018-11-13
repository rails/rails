import consumerTest from "../test_helpers/consumer_test_helper"

const {module} = QUnit

module("ActionCable.Subscriptions", function() {
  consumerTest("create subscription with channel string", function({consumer, server, assert, done}) {
    const channel = "chat"

    server.on("message", function(message) {
      const data = JSON.parse(message)
      assert.equal(data.command, "subscribe")
      assert.equal(data.identifier, JSON.stringify({channel}))
      done()
    })

    consumer.subscriptions.create(channel)
  })

  consumerTest("create subscription with channel object", function({consumer, server, assert, done}) {
    const channel = {channel: "chat", room: "action"}

    server.on("message", function(message) {
      const data = JSON.parse(message)
      assert.equal(data.command, "subscribe")
      assert.equal(data.identifier, JSON.stringify(channel))
      done()
    })

    consumer.subscriptions.create(channel)
  })
})
