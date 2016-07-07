{module, test} = QUnit
{testURL} = ActionCable.TestHelpers

module "ActionCable", ->
  module "#createConsumer", ->
    test "uses specified URL", (assert) ->
      consumer = ActionCable.createConsumer(testURL)
      assert.equal consumer.url, testURL

    test "uses default URL", (assert) ->
      pattern = ///#{ActionCable.INTERNAL.default_mount_path}$///
      consumer = ActionCable.createConsumer()
      assert.ok pattern.test(consumer.url), "Expected #{consumer.url} to match #{pattern}"

    test "uses URL from meta tag", (assert) ->
      element = document.createElement("meta")
      element.setAttribute("name", "action-cable-url")
      element.setAttribute("content", testURL)

      document.head.appendChild(element)
      consumer = ActionCable.createConsumer()
      document.head.removeChild(element)

      assert.equal consumer.url, testURL
