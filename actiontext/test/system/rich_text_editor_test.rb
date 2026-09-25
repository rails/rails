# frozen_string_literal: true

require "application_system_test_case"

class ActionText::RichTextEditorTest < ApplicationSystemTestCase
  test "attaches and uploads image file" do
    image_file = file_fixture("racecar.jpg")

    visit new_message_url
    attach_file image_file do
      click_button "Attach Files"
    end
    within :rich_text_area do
      assert_selector :element, "img", src: %r{/rails/active_storage/blobs/redirect/.*/#{image_file.basename}\Z}
    end
    click_button "Create Message"

    within class: "trix-content" do
      assert_selector :element, "img", src: %r{/rails/active_storage/representations/redirect/.*/#{image_file.basename}\Z}
    end
  end

  test "dispatches direct-upload:-prefixed events when uploading a File" do
    image_file = file_fixture("racecar.jpg")

    visit new_message_url
    events = capture_direct_upload_events do
      attach_file image_file do
        click_button "Attach Files"
      end

      assert_selector :element, "img", src: %r{/rails/active_storage/blobs/redirect/.*/#{image_file.basename}\Z}
    end

    assert_equal 1, ActiveStorage::Blob.where(filename: image_file.basename.to_s).count
    assert_direct_upload_event events[0], "initialize"
    assert_direct_upload_event events[1], "start"
    assert_direct_upload_event events[2], "before-blob-request", xhr: "XMLHttpRequest"
    assert_direct_upload_event events[3], "before-storage-request", xhr: "XMLHttpRequest"
    assert_direct_upload_event events[4], "progress", progress: "Number"
    assert_direct_upload_event events[5], "end"
  end

  test "dispatches direct-upload:error event when uploading fails" do
    image_file = file_fixture("racecar.jpg")

    visit new_message_url
    events = capture_direct_upload_events offline: true do
      accept_alert "Error creating Blob for \"#{image_file.basename}\". Status: 0" do
        attach_file image_file do
          click_button "Attach Files"
        end
      end

      assert_no_selector :element, "img", src: /#{image_file.basename}\Z/
    end

    assert_empty ActiveStorage::Blob.where(filename: image_file.basename.to_s)
    assert_direct_upload_event events.last, "error", error: "String"
  end

  def assert_direct_upload_event(event, name, target: find(:rich_text_area), **detail)
    detail.with_defaults!(id: "Number", file: "File", attachment: "ManagedAttachment")

    assert_equal({ type: "direct-upload:#{name}", target: target, detail: detail }, event)
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
