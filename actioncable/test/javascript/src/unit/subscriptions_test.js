import consumerTest from "../test_helpers/consumer_test_helper"

const {module} = QUnit

module("ActionCable.Subscriptions", () => {
  consumerTest("create subscription with channel string", ({consumer, server, assert, done}) => {
    const channel = "chat"

    server.on("message", (message) => {
      const data = JSON.parse(message)
      assert.equal(data.command, "subscribe")
      assert.equal(data.identifier, JSON.stringify({channel}))
      done()
    })

    consumer.subscriptions.create(channel)
  })

  consumerTest("create subscription with channel object", ({consumer, server, assert, done}) => {
    const channel = {channel: "chat", room: "action"}

    server.on("message", (message) => {
      const data = JSON.parse(message)
      assert.equal(data.command, "subscribe")
      assert.equal(data.identifier, JSON.stringify(channel))
      done()
    })

    consumer.subscriptions.create(channel)
  })

  consumerTest("subscribe only once when two subscriptions use the same channel", ({consumer, server, assert, done}) => {
    const channel = "chat"
    let messageReceived = 0
    
    server.on("message", (message) => {
      messageReceived++
      const data = JSON.parse(message)
      assert.equal(data.identifier, JSON.stringify({channel}))

      switch (messageReceived) {
        case 1:
          assert.equal(data.command, "subscribe")
          break
        case 2:
          assert.equal(data.command, "message")
          assert.deepEqual(data.data, JSON.stringify({action: { subscriptionNumber: 1 }}))
          break
        case 3:
          assert.equal(data.command, "message")
          assert.deepEqual(data.data, JSON.stringify({action: { subscriptionNumber: 2 }}))
          done()
          break
      }
    })

    consumer.subscriptions.create(channel, {
      connected() {
        this.perform({subscriptionNumber: 1})
      }
    })

    const subscription = consumer.subscriptions.create(channel, {
      connected() {
        this.perform({subscriptionNumber: 2})
      }
    })

    server.broadcastTo(subscription, {message_type: "confirmation"})
  })
})
