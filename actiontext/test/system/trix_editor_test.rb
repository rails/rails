# frozen_string_literal: true

require "application_system_test_case"
require "active_support/core_ext/object/with"

class TrixEditorTest < ApplicationSystemTestCase
  test "uploads, attaches, and edits image file" do
    image_file = file_fixture("racecar.jpg")

    with_editor :trix do
      visit new_message_url
      attach_file(image_file) { click_button "Attach Files" }

      within :rich_text_area do
        assert_active_storage_blob image_file
      end

      click_button "Create Message"

      within class: "trix-content" do
        assert_active_storage_representation image_file
      end

      click_link "Edit"

      within :rich_text_area do
        assert_active_storage_blob image_file
      end

      click_button "Update Message"

      within class: "trix-content" do
        assert_active_storage_representation image_file
      end
    end
  end

  test "attaches attachable Record" do
    alice = people(:alice)

    with_editor :trix do
      visit new_message_url
      click_button "Mention #{alice.name}"

      within :rich_text_area do
        assert_editor_attachment alice do
          assert_css "span", text: alice.name, class: "mentionable-person"
        end
      end

      click_button "Create Message"

      within class: "trix-content" do
        assert_css "span", text: alice.name, class: "mentioned-person"
      end

      click_link "Edit"

      within :rich_text_area do
        assert_editor_attachment alice do
          assert_css "span", text: alice.name, class: "mentionable-person"
        end
      end

      click_button "Update Message"

      within class: "trix-content" do
        assert_css "span", text: alice.name, class: "mentioned-person"
      end
    end
  end

  def assert_editor_attachment(attachable, &block)
    attachment_attribute = "data-trix-attachment"

    assert_element "figure", :contenteditable => "false", attachment_attribute.to_sym => true do |figure|
      attachment = JSON.parse(figure[attachment_attribute])

      attachment["sgid"] == attachable.attachable_sgid && within(figure, &block)
    end
  end

  def assert_active_storage_blob(image_file)
    src = %r{/rails/active_storage/blobs/redirect/.*/#{image_file.basename}\Z}

    assert_selector :element, "img", src: src
  end

  def assert_active_storage_representation(image_file)
    src = %r{/rails/active_storage/representations/redirect/.*/#{image_file.basename}\Z}

    assert_selector :element, "img", src: src
  end

  def with_editor(editor_name, &block)
    Rails.configuration.action_text.with(editor: editor_name, &block)
  end
end
