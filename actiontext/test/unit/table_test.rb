# frozen_string_literal: true

require "test_helper"

class ActionText::ModelTest < ActiveSupport::TestCase
  include QueryHelpers

  test "table html conversion" do
    message = Message.new(subject: "Greetings", content: "<h1>Hello world</h1>")
    assert_equal %Q(<div class="trix-content">\n  <h1>Hello world</h1>\n</div>\n), "#{message.content}"
  end

  test "table plain text conversion" do
    message = Message.new(subject: "Greetings", content: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.content.to_plain_text
  end

  test "table without content" do
    message = Message.create!(subject: "Greetings")
    assert message.content.nil?
    assert message.content.blank?
    assert message.content.empty?
    assert_not message.content?
    assert_not message.content.present?
  end

  test "table with blank content" do
    message = Message.create!(subject: "Greetings", content: "")
    assert_not message.content.nil?
    assert message.content.blank?
    assert message.content.empty?
    assert_not message.content?
    assert_not message.content.present?
  end

  test "table embed extraction" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    message = Message.create!(subject: "Greetings", content: ActionText::Content.new("Hello world").append_attachables(blob))
    assert_equal "racecar.jpg", message.content.embeds.first.filename.to_s
  end

  test "table embed extraction only extracts file attachments" do
    remote_image_html = '<action-text-attachment content-type="image" url="http://example.com/cat.jpg"></action-text-attachment>'
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    content = ActionText::Content.new(remote_image_html).append_attachables(blob)
    message = Message.create!(subject: "Greetings", content: content)
    assert_equal [ActionText::Attachables::RemoteImage, ActiveStorage::Blob], message.content.body.attachables.map(&:class)
    assert_equal [ActiveStorage::Attachment], message.content.embeds.map(&:class)
  end

  test "table embed extraction deduplicates file attachments" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    content = ActionText::Content.new("Hello world").append_attachables([ blob, blob ])

    assert_nothing_raised do
      Message.create!(subject: "Greetings", content: content)
    end
  end

  test "table saving content" do
    message = Message.create!(subject: "Greetings", content: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.content.to_plain_text
  end

  test "table duplicating content" do
    message = Message.create!(subject: "Greetings", content: "<b>Hello!</b>")
    other_message = Message.create!(subject: "Greetings", content: message.content)

    assert_equal message.content.body.to_html, other_message.content.body.to_html
  end

  test "table saving body" do
    message = Message.create(subject: "Greetings", body: "<h1>Hello world</h1>")
    assert_equal "Hello world", message.body.to_plain_text
  end

  test "table saving content via nested attributes" do
    message = Message.create! subject: "Greetings", content: "<h1>Hello world</h1>",
      review_attributes: { author_name: "Marcia", content: "Nice work!" }
    assert_equal "Nice work!", message.review.content.to_plain_text
  end

  test "table updating content via nested attributes" do
    message = Message.create! subject: "Greetings", content: "<h1>Hello world</h1>",
      review_attributes: { author_name: "Marcia", content: "Nice work!" }

    message.update! review_attributes: { id: message.review.id, content: "Great work!" }
    assert_equal "Great work!", message.review.reload.content.to_plain_text
  end

  test "table building content lazily on existing record" do
    message = Message.create!(subject: "Greetings")

    assert_no_difference -> { ActionText::RichText.count } do
      assert_kind_of ActionText::RichText, message.content
    end
  end

  test "table eager loading" do
    Message.create!(subject: "Subject", content: "<h1>Content</h1>")

    message = assert_queries(2) { Message.with_rich_text_content.last }
    assert_no_queries do
      assert_equal "Content", message.content.to_plain_text
    end
  end

  test "table eager loading all rich text" do
    Message.create!(subject: "Subject", content: "<h1>Content</h1>", body: "<h2>Body</h2>")

    message = assert_queries(1) { Message.with_all_rich_text.last }
    assert_no_queries do
      assert_equal "Content", message.content.to_plain_text
      assert_equal "Body", message.body.to_plain_text
    end
  end
end
