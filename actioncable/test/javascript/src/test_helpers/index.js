import ActionCable from "./consumer_test_helper"

ActionCable.TestHelpers = {
  testURL: "ws://cable.example.com/",

  defer(callback) {
    return setTimeout(callback, 1);
  }
};

const originalWebSocket = ActionCable.WebSocket;
QUnit.testDone(() => ActionCable.WebSocket = originalWebSocket);

export {ActionCable}
