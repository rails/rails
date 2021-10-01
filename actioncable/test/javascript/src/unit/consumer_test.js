import consumerTest from "../test_helpers/consumer_test_helper"

const {module} = QUnit

module("ActionCable.Consumer", () => {
  consumerTest("#connect", {connect: false}, ({consumer, server, assert, done}) => {
    server.on("connection", () => {
      assert.equal(consumer.connect(), false)
      done()
    })

    consumer.connect()
  })

  consumerTest("#disconnect", ({consumer, client, done}) => {
    client.addEventListener("close", done)
    consumer.disconnect()
  })

  consumerTest("createWebSocketURL", {connect: false, url: "http://example.com:3000/cable?token=token"}, ({consumer, assert, done}) => {
    assert.equal(consumer.url, "ws://example.com:3000/cable?token=token")
    done()
  })

  consumerTest("createWebSocketURL", {connect: false, url: "https://example.com:3000/cable?token=token"}, ({consumer, assert, done}) => {
    assert.equal(consumer.url, "wss://example.com:3000/cable?token=token")
    done()
  })
})
