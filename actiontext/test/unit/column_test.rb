# frozen_string_literal: true

require "test_helper"

class ActionText::ColumnTest < ActiveSupport::TestCase
  include QueryHelpers

  test "html conversion" do
    message = Message.new(subject: "Greetings", rich_content: "<h1>Hello world</h1>")
    assert_equal %Q(<div class="trix-content">\n  <h1>Hello world</h1>\n</div>\n), "#{message.rich_content}"
  end

  test "plain text conversion" do
    message = Message.new(subject: "Greetings", rich_content: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.rich_content.to_plain_text
  end

  test "without content" do
    message = Message.create!(subject: "Greetings")
    assert message.rich_content.nil?
    assert message.rich_content.blank?
    assert message.rich_content.empty?
    assert_not message.rich_content?
    assert_not message.rich_content.present?
  end

  test "with blank content" do
    message = Message.create!(subject: "Greetings", rich_content: "")
    assert_not message.rich_content.nil?
    assert message.rich_content.blank?
    assert message.rich_content.empty?
    assert_not message.rich_content?
    assert_not message.rich_content.present?
  end

  test "embed extraction" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    message = Message.create!(subject: "Greetings", rich_content: ActionText::Content.new("Hello world").append_attachables(blob))
    assert_equal "racecar.jpg", message.rich_content.embeds.first.filename.to_s
  end

  test "embed extraction only extracts file attachments" do
    remote_image_html = '<action-text-attachment content-type="image" url="http://example.com/cat.jpg"></action-text-attachment>'
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    content = ActionText::Content.new(remote_image_html).append_attachables(blob)
    message = Message.create!(subject: "Greetings", rich_content: content)
    assert_equal [ActionText::Attachables::RemoteImage, ActiveStorage::Blob], message.rich_content.body.attachables.map(&:class)
    assert_equal [ActiveStorage::Attachment], message.rich_content.embeds.map(&:class)
  end

  test "embed extraction deduplicates file attachments" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    content = ActionText::Content.new("Hello world").append_attachables([ blob, blob ])

    assert_nothing_raised do
      Message.create!(subject: "Greetings", rich_content: content)
    end
  end

  test "saving content" do
    message = Message.create!(subject: "Greetings", rich_content: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.rich_content.to_plain_text
  end

  test "duplicating content" do
    message = Message.create!(subject: "Greetings", rich_content: "<b>Hello!</b>")
    other_message = Message.create!(subject: "Greetings", rich_content: message.rich_content)

    assert_equal message.rich_content.body.to_html, other_message.rich_content.body.to_html
  end

  test "saving body" do
    message = Message.create(subject: "Greetings", body: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.body.to_plain_text
  end

  test "saving content via nested attributes" do
    message = Message.create! subject: "Greetings", rich_content: "<h1>Hello world</h1>",
      review_attributes: { author_name: "Marcia", rich_content: "Nice work!" }
    assert_equal "Nice work!", message.review.rich_content.to_plain_text
  end

  test "updating content via nested attributes" do
    message = Message.create! subject: "Greetings", rich_content: "<h1>Hello world</h1>",
      review_attributes: { author_name: "Marcia", rich_content: "Nice work!" }

    message.update! review_attributes: { id: message.review.id, rich_content: "Great work!" }
    assert_equal "Great work!", message.review.reload.rich_content.to_plain_text
  end
end
