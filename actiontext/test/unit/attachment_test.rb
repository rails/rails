# frozen_string_literal: true

require "test_helper"

class ActionText::AttachmentTest < ActiveSupport::TestCase
  test "from_attachable" do
    attachment = ActionText::Attachment.from_attachable(attachable, caption: "Captioned")
    assert_equal attachable, attachment.attachable
    assert_equal "Captioned", attachment.caption
  end

  test "proxies missing methods to attachable" do
    attachable.instance_eval { def proxied; "proxied"; end }
    attachment = ActionText::Attachment.from_attachable(attachable)
    assert_equal "proxied", attachment.proxied
  end

  test "proxies #to_param to attachable" do
    attachment = ActionText::Attachment.from_attachable(attachable)
    assert_equal attachable.to_param, attachment.to_param
  end

  test "converts to TrixAttachment" do
    attachment = attachment_from_html(%Q(<action-text-attachment sgid="#{attachable.attachable_sgid}" caption="Captioned"></action-text-attachment>))

    trix_attachment = attachment.to_trix_attachment
    assert_kind_of ActionText::TrixAttachment, trix_attachment

    assert_equal attachable.attachable_sgid, trix_attachment.attributes["sgid"]
    assert_equal attachable.attachable_content_type, trix_attachment.attributes["contentType"]
    assert_equal attachable.filename.to_s, trix_attachment.attributes["filename"]
    assert_equal attachable.byte_size, trix_attachment.attributes["filesize"]
    assert_equal "Captioned", trix_attachment.attributes["caption"]

    assert_nil attachable.to_trix_content_attachment_partial_path
    assert_nil trix_attachment.attributes["content"]
  end

  test "converts to TrixAttachment with content" do
    attachable = Person.create! name: "Javan"
    attachment = attachment_from_html(%Q(<action-text-attachment sgid="#{attachable.attachable_sgid}"></action-text-attachment>))

    trix_attachment = attachment.to_trix_attachment
    assert_kind_of ActionText::TrixAttachment, trix_attachment

    assert_equal attachable.attachable_sgid, trix_attachment.attributes["sgid"]
    assert_equal attachable.attachable_content_type, trix_attachment.attributes["contentType"]

    assert_not_nil attachable.to_trix_content_attachment_partial_path
    assert_not_nil trix_attachment.attributes["content"]
  end

  test "converts to plain text" do
    assert_equal "[Vroom vroom]", ActionText::Attachment.from_attachable(attachable, caption: "Vroom vroom").to_plain_text
    assert_equal "[racecar.jpg]", ActionText::Attachment.from_attachable(attachable).to_plain_text
  end

  test "defaults trix partial to model partial" do
    attachable = Page.create! title: "Homepage"
    assert_equal "pages/page", attachable.to_trix_content_attachment_partial_path
  end

  test "preview blob url for MP4 video" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")
    blob.preview(resize_to_limit: [100, 100]).processed
    message = Message.create!(subject: "Greetings", content: ActionText::Content.new("Hello world").append_attachables(blob))

    attachment = attachment_from_html(message.content.body.to_trix_html)

    trix_attachment = attachment.to_trix_attachment
    assert_kind_of ActionText::TrixAttachment, trix_attachment

    assert_equal blob.attachable_sgid, trix_attachment.attributes["sgid"]
    assert_equal blob.attachable_content_type, trix_attachment.attributes["contentType"]
    assert_equal Rails.application.routes.url_helpers.rails_blob_url(blob.preview_image, only_path: true), trix_attachment.attributes["url"]
  end

  private
    def attachment_from_html(html)
      ActionText::Content.new(html).attachments.first
    end

    def attachable
      @attachment ||= create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    end
end
