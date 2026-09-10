# frozen_string_literal: true

require "test_helper"

class ActionText::MarkdownSanitizationTest < ActionDispatch::IntegrationTest
  PAYLOAD     = "[click](javascript:alert(1))"
  WITH_MARKER = "<action-text-markdown>#{PAYLOAD}</action-text-markdown>".freeze
  ESCAPED     = "\\[click\\](javascript:alert(1))"

  test "a submitted body is stored without the raw Markdown tag it arrived with" do
    post messages_path, params: { message: { subject: "x", content: WITH_MARKER } }

    assert_equal PAYLOAD, Message.last.rich_text_content.read_attribute_before_type_cast(:body)
  end

  test "wrapping the payload in the raw Markdown tag grants it no privilege" do
    assert_equal markdown_for(PAYLOAD), markdown_for(WITH_MARKER)
  end

  test "a body persisted with the raw Markdown tag is stripped when it is loaded" do
    post messages_path, params: { message: { subject: "x", content: PAYLOAD } }
    rich_text = Message.last.rich_text_content
    rich_text.update_column(:body, ActionText::Content.new(WITH_MARKER, canonicalize: false))

    assert_equal ESCAPED, rich_text.reload.body.to_markdown
  end

  private
    def markdown_for(content)
      post messages_path, params: { message: { subject: "x", content: content } }
      Message.last.tap(&:reload).content.to_markdown
    end
end
