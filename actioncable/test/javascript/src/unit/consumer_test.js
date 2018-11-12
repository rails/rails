const {module, test} = QUnit
const {consumerTest} = ActionCable.TestHelpers

module("ActionCable.Consumer", function() {
  consumerTest("#connect", {connect: false}, function({consumer, server, assert, done}) {
    server.on("connection", function() {
      assert.equal(consumer.connect(), false)
      done()
    })

    consumer.connect()
  })

  consumerTest("#disconnect", function({consumer, client, done}) {
    client.addEventListener("close", done)
    consumer.disconnect()
  })
})
