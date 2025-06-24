# frozen_string_literal: true

require "test_helper"

class ActionText::FormHelperTest < ActionView::TestCase
  tests ActionText::TagHelper

  def form_with(*, **)
    @output_buffer = super
  end

  teardown do
    I18n.backend.reload!
  end

  setup do
    I18n.backend.store_translations("placeholder",
      activerecord: {
        attributes: {
          message: {
            title: "Story title"
          }
        }
      }
    )
  end

  test "#rich_textarea_tag helper" do
    message = Message.new

    concat rich_textarea_tag :content, message.content, { input: "trix_input_1" }

    assert_dom_equal \
      '<input type="hidden" name="content" id="trix_input_1" autocomplete="off" />' \
      '<trix-editor input="trix_input_1" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
      "</trix-editor>",
      output_buffer
  end

  test "#rich_textarea helper" do
    concat rich_textarea :message, :content, input: "trix_input_1"

    assert_dom_equal \
      '<input type="hidden" name="message[content]" id="trix_input_1" autocomplete="off" />' \
      '<trix-editor id="message_content" input="trix_input_1" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
      "</trix-editor>",
      output_buffer
  end

  test "#rich_textarea helper renders the :value argument into the hidden field" do
    message = Message.new content: "<h1>hello world</h1>"

    concat rich_textarea :message, :title, value: message.content, input: "trix_input_1"

    assert_dom_equal \
      '<input type="hidden" name="message[title]" id="trix_input_1" value="&lt;h1&gt;hello world&lt;/h1&gt;" autocomplete="off" />' \
      '<trix-editor id="message_title" input="trix_input_1" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
      "</trix-editor>",
      output_buffer
  end

  test "form with rich text area" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_textarea :content
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[content]" id="message_content_trix_input_message" autocomplete="off" />' \
        '<trix-editor id="message_content" input="message_content_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area having class" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_textarea :content, class: "custom-class"
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[content]" id="message_content_trix_input_message" autocomplete="off" />' \
        '<trix-editor id="message_content" input="message_content_trix_input_message" class="custom-class" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area and error wrapper" do
    message = Message.new
    message.errors.add(:content, :blank)

    form_with model: message, scope: :message do |form|
      form.rich_textarea :content
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<div class="field_with_errors">' \
            '<input type="hidden" name="message[content]" id="message_content_trix_input_message" autocomplete="off" />' \
            '<trix-editor id="message_content" input="message_content_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
            "</trix-editor>" \
          "</div>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area for non-attribute" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_textarea :not_an_attribute
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[not_an_attribute]" id="message_not_an_attribute_trix_input_message" autocomplete="off" />' \
        '<trix-editor id="message_not_an_attribute" input="message_not_an_attribute_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "modelless form with rich text area" do
    form_with url: "/messages", scope: :message do |form|
      form.rich_textarea :content, { input: "trix_input_2" }
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[content]" id="trix_input_2" autocomplete="off" />' \
        '<trix-editor id="message_content" input="trix_input_2" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area having placeholder without locale" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_textarea :content, placeholder: true
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[content]" id="message_content_trix_input_message" autocomplete="off" />' \
        '<trix-editor placeholder="Content" id="message_content" input="message_content_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area having placeholder with locale" do
    I18n.with_locale :placeholder do
      form_with model: Message.new, scope: :message do |form|
        form.rich_textarea :title, placeholder: true
      end
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[title]" id="message_title_trix_input_message" autocomplete="off" />' \
        '<trix-editor placeholder="Story title" id="message_title" input="message_title_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area with value" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_textarea :title, value: "<h1>hello world</h1>"
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[title]" id="message_title_trix_input_message" value="&lt;h1&gt;hello world&lt;/h1&gt;" autocomplete="off" />' \
        '<trix-editor id="message_title" input="message_title_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area with form attribute" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_textarea :title, form: "other_form"
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[title]" id="message_title_trix_input_message" form="other_form" autocomplete="off" />' \
        '<trix-editor id="message_title" input="message_title_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area with data[direct_upload_url]" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_textarea :content, data: { direct_upload_url: "http://test.host/direct_uploads" }
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[content]" id="message_content_trix_input_message" autocomplete="off" />' \
        '<trix-editor id="message_content" input="message_content_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/redirect/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end

  test "form with rich text area with data[blob_url_template]" do
    form_with model: Message.new, scope: :message do |form|
      form.rich_textarea :content, data: { blob_url_template: "http://test.host/blobs/:signed_id/:filename" }
    end

    assert_dom_equal \
      '<form action="/messages" accept-charset="UTF-8" method="post">' \
        '<input type="hidden" name="message[content]" id="message_content_trix_input_message" autocomplete="off" />' \
        '<trix-editor id="message_content" input="message_content_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/blobs/:signed_id/:filename">' \
        "</trix-editor>" \
      "</form>",
      output_buffer
  end
end
