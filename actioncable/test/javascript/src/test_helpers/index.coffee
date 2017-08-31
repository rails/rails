#= require_self
#= require_tree .

ActionCable.TestHelpers =
  testURL: "ws://cable.example.com/"

  defer: (callback) ->
    setTimeout(callback, 1)

originalWebSocket = ActionCable.WebSocket
QUnit.testDone -> ActionCable.WebSocket = originalWebSocket
