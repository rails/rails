# frozen_string_literal: true

require "test_helper"

class ActionText::AttributeTest < ActiveSupport::TestCase
  test "html conversion" do
    post = Post.new(title: "Greetings", custom_body: "<h1>Hello world</h1>")
    assert_equal %Q(<div class="trix-content">\n  <h1>Hello world</h1>\n</div>\n), "#{post.custom_body}"
  end

  test "plain text conversion" do
    post = Post.new(title: "Greetings", custom_body: "<h1>Hello world</h1>")
    assert_equal "Hello world", post.custom_body.to_plain_text
  end

  test "without content" do
    post = Post.create!(title: "Greetings")
    assert post.custom_body.nil?
    assert post.custom_body.blank?
    assert_not post.custom_body.present?
  end

  test "with blank content" do
    post = Post.create!(title: "Greetings", custom_body: "")
    assert_not post.custom_body.nil?
    assert post.custom_body.blank?
    assert post.custom_body.empty?
    assert_not post.custom_body.present?
  end

  test "embed extraction" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    post = Post.create!(title: "Greetings", custom_body: ActionText::Content.new("Hello world").append_attachables(blob))
    assert_equal "racecar.jpg", post.custom_body_attachments.first.filename.to_s
  end

  test "embed extraction only extracts file attachments" do
    remote_image_html = '<action-text-attachment content-type="image" url="http://example.com/cat.jpg"></action-text-attachment>'
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    content = ActionText::Content.new(remote_image_html).append_attachables(blob)
    post = Post.create!(title: "Greetings", custom_body: content)
    assert_equal [ActionText::Attachables::RemoteImage, ActiveStorage::Blob], post.custom_body.attachables.map(&:class)
    assert_equal [ActiveStorage::Attachment], post.custom_body_attachments.map(&:class)
  end

  test "embed extraction deduplicates file attachments" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    content = ActionText::Content.new("Hello world").append_attachables([ blob, blob ])

    assert_nothing_raised do
      Post.create!(title: "Greetings", custom_body: content)
    end
  end

  test "saving custom_body" do
    post = Post.create(title: "Greetings", custom_body: "<h1>Hello world</h1>")
    assert_equal "Hello world", post.custom_body.to_plain_text
  end

  test "saving content via nested attributes" do
    post = Post.create! title: "Greetings", custom_body: "<h1>Hello world</h1>",
      comments_attributes: [{ author_name: "Marcia", comment_contents: "Nice work!" }]
    assert_equal "Nice work!", post.comments.first.comment_contents.to_plain_text
  end

  test "updating content via nested attributes" do
    post = Post.create! title: "Greetings", custom_body: "<h1>Hello world</h1>",
      comments_attributes: [{ author_name: "Marcia", comment_contents: "Nice work!" }]

    post.update! comments_attributes: { id: post.comments.first.id, comment_contents: "Great work!" }
    assert_equal "Great work!", post.comments.first.reload.comment_contents.to_plain_text
  end
end
