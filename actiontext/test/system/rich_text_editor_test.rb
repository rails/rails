# frozen_string_literal: true

require "application_system_test_case"

class ActionText::RichTextEditorTest < ApplicationSystemTestCase
  test "attaches and uploads image file" do
    visit new_message_url
    attach_rich_text_file file_fixture("racecar.jpg")
    within :rich_text_area do
      assert_selector :element, "img", src: %r{/rails/active_storage/blobs/redirect/.*/racecar.jpg\Z}
    end
    click_button "Create Message"

    within class: "trix-content" do
      assert_selector :element, "img", src: %r{/rails/active_storage/representations/redirect/.*/racecar.jpg\Z}
    end
  end

  test "dispatches direct-upload:-prefixed events when uploading a File" do
    visit new_message_url
    events = capture_direct_upload_events do
      attach_rich_text_file file_fixture("racecar.jpg")

      assert_selector :element, "img", src: %r{/rails/active_storage/blobs/redirect/.*/racecar.jpg\Z}
    end

    assert_equal 1, ActiveStorage::Blob.where(filename: "racecar.jpg").count
    assert_direct_upload_event events[0], "initialize"
    assert_direct_upload_event events[1], "start"
    assert_direct_upload_event events[2], "before-blob-request", xhr: "XMLHttpRequest"
    assert_direct_upload_event events[3], "before-storage-request", xhr: "XMLHttpRequest"
    assert_direct_upload_event events[4], "progress", progress: "Number"
    assert_direct_upload_event events[5], "end"
  end

  test "dispatches direct-upload:error event when uploading fails" do
    visit new_message_url
    events = capture_direct_upload_events offline: true do
      accept_alert 'Error creating Blob for "racecar.jpg". Status: 0' do
        attach_rich_text_file file_fixture("racecar.jpg")
      end

      assert_no_selector :element, "img", src: /racecar.jpg\Z/
    end

    assert_empty ActiveStorage::Blob.where(filename: "racecar.jpg")
    assert_direct_upload_event events.last, "error", error: "String"
  end

  def assert_direct_upload_event(event, name, target: find(:rich_text_area), **detail)
    detail.with_defaults!(id: "Number", file: "File", attachment: "ManagedAttachment")

    assert_equal({ type: "direct-upload:#{name}", target: target, detail: detail }, event)
  end

  def attach_rich_text_file(*args)
    attach_file(*args) { click_button "Attach Files" }
  end

  def capture_direct_upload_events(offline: false, &block)
    event_names = %w[
      direct-upload:initialize
      direct-upload:start
      direct-upload:before-blob-request
      direct-upload:before-storage-request
      direct-upload:progress
      direct-upload:error
      direct-upload:end
    ]
    execute_script <<~JS, *event_names
      window.capturedEvents = []

      for (const eventName of arguments) {
        addEventListener(eventName, ({ target, type, detail }) => {
          const serialized = {}

          for (const name in detail) {
            serialized[name] = detail[name].constructor.name
          }

          window.capturedEvents.push({ target, type, detail: serialized })
        }, { once: true })
      }
    JS

    while_offline(offline, &block)

    evaluate_script("window.capturedEvents").map(&:deep_symbolize_keys!)
  end

  def while_offline(value, &block)
    # raises unknown error: network conditions must be set before it can be retrieved
    # unless set to an initial value
    page.driver.browser.network_conditions = { offline: !value }

    page.driver.browser.with(network_conditions: { offline: value }, &block)
  end
end
