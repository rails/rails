import * as ActionCable from "../../../../app/javascript/action_cable/index"

export const testURL = "ws://cable.example.com/"

export function defer(callback) {
  setTimeout(callback, 1)
}

const originalWebSocket = ActionCable.adapters.WebSocket
QUnit.testDone(() => ActionCable.adapters.WebSocket = originalWebSocket)
