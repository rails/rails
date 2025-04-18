# frozen_string_literal: true

require "application_system_test_case"

class ActionText::SystemTestHelperTest < ApplicationSystemTestCase
  def setup
    visit new_message_url
  end

  test "filling in a rich-text area by ID" do
    assert_selector :element, "trix-editor", id: "message_content"
    fill_in_rich_textarea "message_content", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in a rich-text area by placeholder" do
    assert_selector :element, "trix-editor", placeholder: "Your message here"
    fill_in_rich_textarea "Your message here", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in a rich-text area by aria-label" do
    assert_selector :element, "trix-editor", "aria-label": "Message content aria-label"
    fill_in_rich_textarea "Message content aria-label", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in a rich-text area by label" do
    assert_selector :label, "Message content label", for: "message_content"
    fill_in_rich_textarea "Message content label", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in a rich-text area by input name" do
    assert_selector :element, "trix-editor", input: true
    fill_in_rich_textarea "message[content]", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in the only rich-text area" do
    fill_in_rich_textarea with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end
end
