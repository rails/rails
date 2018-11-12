{module, test} = QUnit
{consumerTest} = ActionCable.TestHelpers

module "ActionCable.Subscriptions", ->
  consumerTest "create subscription with channel string", ({consumer, server, assert, done}) ->
    channel = "chat"

    server.on "message", (message) ->
      data = JSON.parse(message)
      assert.equal data.command, "subscribe"
      assert.equal data.identifier, JSON.stringify({channel})
      done()

    consumer.subscriptions.create(channel)

  consumerTest "create subscription with channel object", ({consumer, server, assert, done}) ->
    channel = channel: "chat", room: "action"

    server.on "message", (message) ->
      data = JSON.parse(message)
      assert.equal data.command, "subscribe"
      assert.equal data.identifier, JSON.stringify(channel)
      done()

    consumer.subscriptions.create(channel)
