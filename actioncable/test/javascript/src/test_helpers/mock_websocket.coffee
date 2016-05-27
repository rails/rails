#= require mock-socket

ActionCable.TestHelpers.MockWebSocket = MockWebSocket

server = null
consumer = null

ActionCable.TestHelpers.createConsumer = (url, callback) ->
  server = new MockServer url
  consumer = ActionCable.createConsumer(url)
  callback(consumer, server)

QUnit.testDone ->
  if consumer?
    consumer.disconnect()

  if server?
    server.clients().forEach (client) -> client.close()
    server.close()
