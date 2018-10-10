# frozen_string_literal: true

require 'test_helper'

class ActionText::FormHelperTest < ActionView::TestCase
  tests ActionText::TagHelper

  def form_with(*)
    @output_buffer = super
  end

  test "rich_text_area doesn't raise when attributes don't exist in the model" do
    assert_nothing_raised do
      form_with(model: Message.new, scope: :message, id: "create-message") do |form|
        form.rich_text_area(:not_an_attribute)
      end
    end

    assert_match "message[not_an_attribute]", output_buffer
  end

  test "form with rich_text_area" do
    expected = '<form id="create-message" action="/messages" accept-charset="UTF-8" data-remote="true" method="post">'\
               '<input name="utf8" type="hidden" value="&#x2713;" />'\
               '<input type="hidden" name="message[content]" id="message_content_trix_input_message" />'\
               '<trix-editor id="message_content" input="message_content_trix_input_message" class="trix-content" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/:signed_id/:filename">'\
               '</trix-editor></form>'

    form_with(model: Message.new, scope: :message, id: "create-message") do |form|
      form.rich_text_area(:content)
    end

    assert_dom_equal expected, output_buffer
  end

  test "form with rich_text_area providing class option" do
    expected = '<form id="create-message" action="/messages" accept-charset="UTF-8" data-remote="true" method="post">'\
                   '<input name="utf8" type="hidden" value="&#x2713;" />'\
                   '<input type="hidden" name="message[content]" id="message_content_trix_input_message" />'\
                   '<trix-editor id="message_content" input="message_content_trix_input_message" class="custom-class" data-direct-upload-url="http://test.host/rails/active_storage/direct_uploads" data-blob-url-template="http://test.host/rails/active_storage/blobs/:signed_id/:filename">'\
                   '</trix-editor></form>'

    form_with(model: Message.new, scope: :message, id: "create-message") do |form|
      form.rich_text_area(:content, class: "custom-class")
    end

    assert_dom_equal expected, output_buffer
  end
end
