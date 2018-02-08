require_relative '../test_helper'

module ActiveText
  class ContentTest < ActiveSupport::TestCase
    test "plain text conversion" do
      content = ActiveText::Content.new("<h1>Hello world</h1>")
      assert "Hello world", content.to_plain_text
    end
  end
end
