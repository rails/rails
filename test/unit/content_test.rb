require_relative '../test_helper'

module ActionText
  class ContentTest < ActiveSupport::TestCase
    test "plain text conversion" do
      message = Message.new(subject: "Greetings", content: "<h1>Hello world</h1>")
      assert_equal "Hello world", message.content.body.to_plain_text
    end
  end
end
