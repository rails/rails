#= require_self
#= require_tree .

ActionCable.TestHelpers =
  testURL: "ws://cable.example.com/"

originalWebSocket = ActionCable.WebSocket
QUnit.testDone -> ActionCable.WebSocket = originalWebSocket
