require_relative '../test_helper'

module ActionText
  class ModelTest < ActiveSupport::TestCase
    test "saving content" do
      message = Message.create!(subject: "Greetings", content: "<h1>Hello world</h1>")
      assert_equal "Hello world", message.content.body.to_plain_text
    end
  end
end
