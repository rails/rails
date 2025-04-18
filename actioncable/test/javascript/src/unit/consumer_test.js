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

  consumerTest("#addSubProtocol", {subprotocols: "some subprotocol"}, ({consumer, server, assert, done}) => {
    server.on("connection", () => {
      assert.equal(consumer.subprotocols.length, 1)
      assert.equal(consumer.subprotocols[0], "some subprotocol")
      done()
    })
  })
})
