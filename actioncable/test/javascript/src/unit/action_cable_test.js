const {module, test} = QUnit;
const {testURL} = ActionCable.TestHelpers;

module("ActionCable", function() {
  module("Adapters", function() {
    module("WebSocket", function() {
      test("default is window.WebSocket", assert => assert.equal(ActionCable.WebSocket, window.WebSocket));

      return test("configurable", function(assert) {
        ActionCable.WebSocket = "";
        return assert.equal(ActionCable.WebSocket, "");
      });
    });

    return module("logger", function() {
      test("default is window.console", assert => assert.equal(ActionCable.logger, window.console));

      return test("configurable", function(assert) {
        ActionCable.logger = "";
        return assert.equal(ActionCable.logger, "");
      });
    });
  });

  return module("#createConsumer", function() {
    test("uses specified URL", function(assert) {
      const consumer = ActionCable.createConsumer(testURL);
      return assert.equal(consumer.url, testURL);
    });

    test("uses default URL", function(assert) {
      const pattern = new RegExp(`${ActionCable.INTERNAL.default_mount_path}$`);
      const consumer = ActionCable.createConsumer();
      return assert.ok(pattern.test(consumer.url), `Expected ${consumer.url} to match ${pattern}`);
    });

    return test("uses URL from meta tag", function(assert) {
      const element = document.createElement("meta");
      element.setAttribute("name", "action-cable-url");
      element.setAttribute("content", testURL);

      document.head.appendChild(element);
      const consumer = ActionCable.createConsumer();
      document.head.removeChild(element);

      return assert.equal(consumer.url, testURL);
    });
  });
});
