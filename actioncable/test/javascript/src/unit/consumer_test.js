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
})
