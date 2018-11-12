const {module, test} = QUnit
const {consumerTest} = ActionCable.TestHelpers

module("ActionCable.Subscription", function() {
  consumerTest("#initialized callback", ({server, consumer, assert, done}) =>
    consumer.subscriptions.create("chat", {
      initialized() {
        assert.ok(true)
        done()
      }
    }
    )
  )

  consumerTest("#connected callback", function({server, consumer, assert, done}) {
    const subscription = consumer.subscriptions.create("chat", {
      connected() {
        assert.ok(true)
        done()
      }
    }
    )

    server.broadcastTo(subscription, {message_type: "confirmation"})
  })

  consumerTest("#disconnected callback", function({server, consumer, assert, done}) {
    const subscription = consumer.subscriptions.create("chat", {
      disconnected() {
        assert.ok(true)
        done()
      }
    }
    )

    server.broadcastTo(subscription, {message_type: "confirmation"}, () => server.close())
  })

  consumerTest("#perform", function({consumer, server, assert, done}) {
    const subscription = consumer.subscriptions.create("chat", {
      connected() {
        this.perform({publish: "hi"})
      }
    }
    )

    server.on("message", function(message) {
      const data = JSON.parse(message)
      assert.equal(data.identifier, subscription.identifier)
      assert.equal(data.command, "message")
      assert.deepEqual(data.data, JSON.stringify({action: { publish: "hi" }}))
      done()
    })

    server.broadcastTo(subscription, {message_type: "confirmation"})
  })
})
