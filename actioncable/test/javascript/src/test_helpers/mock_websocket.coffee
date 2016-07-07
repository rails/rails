#= require mock-socket

NativeWebSocket = window.WebSocket

server = null
consumer = null

ActionCable.TestHelpers.createConsumer = (url, callback) ->
  window.WebSocket = MockWebSocket
  server = new MockServer url
  consumer = ActionCable.createConsumer(url)
  callback(consumer, server)

QUnit.testDone ->
  if consumer?
    consumer.disconnect()

  if server?
    server.clients().forEach (client) -> client.close()
    server.close()
    window.WebSocket = NativeWebSocket
