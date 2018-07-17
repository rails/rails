import {ActionCable} from "../test_helpers/index.js"

const {module, test} = QUnit
const {consumerTest} = ActionCable.TestHelpers

module("ActionCable.Consumer", function() {
  consumerTest("#connect", {connect: false}, function({consumer, server, assert, done}) {
    server.on("connection", function() {
      assert.equal(consumer.connect(), false)
      return done()
    })

    return consumer.connect()
  })

  return consumerTest("#disconnect", function({consumer, client, done}) {
    client.addEventListener("close", done)
    return consumer.disconnect()
  })
})
