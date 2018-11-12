const {module, test} = QUnit
const {testURL} = ActionCable.TestHelpers

module("ActionCable", function() {
  module("Adapters", function() {
    module("WebSocket", function() {
      test("default is window.WebSocket", assert => assert.equal(ActionCable.WebSocket, window.WebSocket))

      test("configurable", function(assert) {
        ActionCable.WebSocket = ""
        assert.equal(ActionCable.WebSocket, "")
      })
    })

    module("logger", function() {
      test("default is window.console", assert => assert.equal(ActionCable.logger, window.console))

      test("configurable", function(assert) {
        ActionCable.logger = ""
        assert.equal(ActionCable.logger, "")
      })
    })
  })

  module("#createConsumer", function() {
    test("uses specified URL", function(assert) {
      const consumer = ActionCable.createConsumer(testURL)
      assert.equal(consumer.url, testURL)
    })

    test("uses default URL", function(assert) {
      const pattern = new RegExp(`${ActionCable.INTERNAL.default_mount_path}$`)
      const consumer = ActionCable.createConsumer()
      assert.ok(pattern.test(consumer.url), `Expected ${consumer.url} to match ${pattern}`)
    })

    test("uses URL from meta tag", function(assert) {
      const element = document.createElement("meta")
      element.setAttribute("name", "action-cable-url")
      element.setAttribute("content", testURL)

      document.head.appendChild(element)
      const consumer = ActionCable.createConsumer()
      document.head.removeChild(element)

      assert.equal(consumer.url, testURL)
    })
  })
})
