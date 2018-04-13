/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
//= require_self
//= require_tree .

ActionCable.TestHelpers = {
  testURL: "ws://cable.example.com/",

  defer(callback) {
    return setTimeout(callback, 1);
  }
};

const originalWebSocket = ActionCable.WebSocket;
QUnit.testDone(() => ActionCable.WebSocket = originalWebSocket);
