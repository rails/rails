# frozen_string_literal: true

require "test_helper"

class ActionText::FormHelperTest < ActionView::TestCase
  tests ActionText::TagHelper

  test "form with rich text area" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_text_area :content
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" data-remote="true" method="post">' \
        '<input type="hidden" name="message[content]" id="message_content_trix_input_message" />' \
        '<trix-editor id="message_content" input="message_content_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area having class" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_text_area :content, class: "custom-class"
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" data-remote="true" method="post">' \
        '<input type="hidden" name="message[content]" id="message_content_trix_input_message" />' \
        '<trix-editor id="message_content" input="message_content_trix_input_message" class="custom-class" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area for non-attribute" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_text_area :not_an_attribute
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" data-remote="true" method="post">' \
        '<input type="hidden" name="message[not_an_attribute]" id="message_not_an_attribute_trix_input_message" />' \
        '<trix-editor id="message_not_an_attribute" input="message_not_an_attribute_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "modelless form with rich text area" do
    form_with url: "/messages", scope: :message do |form|
      form.rich_text_area :content
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" data-remote="true" method="post">' \
        '<input type="hidden" name="message[content]" id="trix_input_1" />' \
        '<trix-editor id="message_content" input="trix_input_1" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  def form_with(*)
    @output_buffer = super
  end
end
