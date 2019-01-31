# frozen_string_literal: true

require "test_helper"

class ActionText::ModelTest < ActiveSupport::TestCase
  test "html conversion" do
    message = Message.new(subject: "Greetings", content: "<h1>Hello world</h1>")
    assert_equal %Q(<div class="trix-content">\n  <h1>Hello world</h1>\n</div>\n), "#{message.content}"
  end

  test "plain text conversion" do
    message = Message.new(subject: "Greetings", content: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.content.to_plain_text
  end

  test "without content" do
    message = Message.create!(subject: "Greetings")
    assert message.content.nil?
    assert message.content.blank?
    assert message.content.empty?
    assert_not message.content.present?
  end

  test "with blank content" do
    message = Message.create!(subject: "Greetings", content: "")
    assert_not message.content.nil?
    assert message.content.blank?
    assert message.content.empty?
    assert_not message.content.present?
  end

  test "embed extraction" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    message = Message.create!(subject: "Greetings", content: ActionText::Content.new("Hello world").append_attachables(blob))
    assert_equal "racecar.jpg", message.content.embeds.first.filename.to_s
  end

  test "embed extraction only extracts file attachments" do
    remote_image_html = '<action-text-attachment content-type="image" url="http://example.com/cat.jpg"></action-text-attachment>'
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    content = ActionText::Content.new(remote_image_html).append_attachables(blob)
    message = Message.create!(subject: "Greetings", content: content)
    assert_equal [ActionText::Attachables::RemoteImage, ActiveStorage::Blob], message.content.body.attachables.map(&:class)
    assert_equal [ActiveStorage::Attachment], message.content.embeds.map(&:class)
  end

  test "saving content" do
    message = Message.create!(subject: "Greetings", content: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.content.to_plain_text
  end

  test "save body" do
    message = Message.create(subject: "Greetings", body: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.body.to_plain_text
  end
end
