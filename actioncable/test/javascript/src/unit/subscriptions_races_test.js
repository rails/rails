import consumerTest from "../test_helpers/consumer_test_helper"
import * as ActionCable from "../../../../app/javascript/action_cable/index"

const {module} = QUnit

// These tests ensure the client prevents race conditions in subscription management caused by the fact that the server process commands concurrently.
// We use the same scenario: rapid subscribe-unsubscribe-subscribe command sequence. Depending on the order of server-side completeness and confirmation message delivery, various state corruptions might occur.
module("ActionCable.Subscriptions race conditions", (hooks) => {
  const originalCooldownInterval = ActionCable.Subscriptions.subscribeCooldownInterval
  hooks.beforeEach(() => ActionCable.Subscriptions.subscribeCooldownInterval = 60)
  hooks.afterEach(() => ActionCable.Subscriptions.subscribeCooldownInterval = originalCooldownInterval)

  // Fast subscribe, slow unsubscribe: the unsubscribe is the last command to complete server-side.
  //
  // Here is the race condition we had previously and want to protect against with this test:
  // - The first subscribe confirms with a short delay; the confirmation is applied to the the second subsription by identifier, so the client believes it is connected.
  // - However, the second subscribe is a no-op (already subscribed server-side).
  // - Then the unsubscribe finally completes and removes the subscription from the server.
  // - The client now holds a "ghost" subscription: connected, but unknown to the server.
  consumerTest("slow unsubscribe should not affect re-subscribe", ({ consumer, server, assert, done }) => {
    let serverSubscriptions = {}

    server.on("message", (message) => {
      const data = JSON.parse(message)
      if (data.command === "subscribe") {
        if (serverSubscriptions[data.identifier]) return

        serverSubscriptions[data.identifier] = true
        setTimeout(() => {
          server.send(JSON.stringify({ identifier: data.identifier, type: ActionCable.INTERNAL.message_types["confirmation"] }))
        }, 20)
      } else if (data.command === "unsubscribe") {
        if (!serverSubscriptions[data.identifier]) return

        // Emulate slow unsubscribed callback
        setTimeout(() => {
          delete serverSubscriptions[data.identifier]
        }, 50)
      }
    })

    let connectedCalled = false

    const first = consumer.subscriptions.create("notifications")
    first.unsubscribe()
    const second = consumer.subscriptions.create("notifications", {
      connected() { connectedCalled = true }
    })

    setTimeout(() => {
      assert.ok(connectedCalled, "client received a confirmation and believes it is subscribed")
      assert.ok(serverSubscriptions[second.identifier], "server agrees the channel is subscribed")
      assert.equal(consumer.subscriptions.guarantor.pendingSubscriptions.length, 0, "no pending subscriptions")
      done()
    }, 100)
  })

  // Slower subscribe, fast unsubscribe: the unsubscribe completes before the first subscribe and no-op, the confirmation arrives in-between unsubscribe and the second subscribe.
  //
  // Reported in https://github.com/rails/rails/issues/44652.
  //
  // Here is the race condition we had previously and want to protect against with this test:
  // - The unsubscribe completes quickly and does nothing (there is no subscription registered yet).
  // - The first subscribe confirms with a delay; the confirmation lands in the gap between the unsubscribe and the re-subscribe, when no subscription is registered for the identifier, so it is ignored by the client.
  // - The second subscribe is a no-op (already subscribed server-side), so its confirmation never comes and the client never fires connected.
  // - The client is stuck pending: the server has the channel subscribed, but the client believes it is not connected.
  consumerTest("fast unsubscribe should not swallow re-subscribe confirmation", ({ consumer, server, assert, done }) => {
    let serverSubscriptions = {}

    server.on("message", (message) => {
      const data = JSON.parse(message)
      if (data.command === "subscribe") {
        // Emulate slow subscribed callback
        setTimeout(() => {
          if (serverSubscriptions[data.identifier]) return

          serverSubscriptions[data.identifier] = true
          server.send(JSON.stringify({ identifier: data.identifier, type: ActionCable.INTERNAL.message_types["confirmation"] }))
        }, 30)
      } else if (data.command === "unsubscribe") {
        // Fast unsubscribed callback
        setTimeout(() => {
          delete serverSubscriptions[data.identifier]
        }, 5)
      }
    })

    let connectedCalled = false

    const first = consumer.subscriptions.create("slow_notifications")
    first.unsubscribe()

    // Re-subscribe only after the stale confirmation (~30ms) has come and gone, so it lands in the gap and is ignored.
    setTimeout(() => {
      const second = consumer.subscriptions.create("slow_notifications", {
        connected() { connectedCalled = true }
      })

      setTimeout(() => {
        assert.ok(connectedCalled, "client received a confirmation and believes it is subscribed")
        assert.ok(serverSubscriptions[second.identifier], "server agrees the channel is subscribed")
        assert.equal(consumer.subscriptions.guarantor.pendingSubscriptions.length, 0, "no pending subscriptions")
        done()
      }, 150)
    }, 50)
  })
})
