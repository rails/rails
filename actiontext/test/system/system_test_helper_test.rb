# frozen_string_literal: true

require "application_system_test_case"

class ActionText::SystemTestHelperTest < ApplicationSystemTestCase
  test "filling in a rich-text area by ID" do
    visit new_message_url
    assert_selector "trix-editor#message_content"
    fill_in_rich_text_area "message_content", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in a rich-text area by placeholder" do
    visit new_message_url
    assert_selector "trix-editor[placeholder='Your message here']"
    fill_in_rich_text_area "Your message here", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in a rich-text area by aria-label" do
    visit new_message_url
    assert_selector "trix-editor[aria-label='Message content aria-label']"
    fill_in_rich_text_area "Message content aria-label", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in a rich-text area by label" do
    visit new_message_url
    assert_selector "label", text: "Message content label"
    fill_in_rich_text_area "Message content label", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in a rich-text area by input name" do
    visit new_message_url
    assert_selector "trix-editor[input]"
    fill_in_rich_text_area "message[content]", with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end

  test "filling in the only rich-text area" do
    visit new_message_url
    fill_in_rich_text_area with: "Hello world!"
    assert_selector :field, "message[content]", with: /Hello world!/, type: "hidden"
  end
end
