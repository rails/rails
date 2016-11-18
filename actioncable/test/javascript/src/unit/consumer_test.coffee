{module, test} = QUnit
{consumerTest} = ActionCable.TestHelpers

module "ActionCable.Consumer", ->
  consumerTest "#connect", connect: false, ({consumer, server, done}) ->
    server.on("connection", done)
    consumer.connect()

  consumerTest "#disconnect", ({consumer, client, done}) ->
    client.addEventListener("close", done)
    consumer.disconnect()
