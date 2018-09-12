require_relative '../test_helper'

module ActionText
  class ContentTest < ActiveSupport::TestCase
    test "plain text conversion" do
      message = Message.new(subject: "Greetings", content: "<h1>Hello world</h1>")
      assert_equal "Hello world", message.content.body.to_plain_text
    end

    test "creating a model with rich text content will not create a rich text record" do
      message = Message.create!(subject: "Greetings")
      assert message.content.body.nil?
    end

    test "removing content removes the rich text record" do
      message = Message.create!(subject: "Greetings", content: "<h1>Hello world</h1>")
      
      assert_difference -> { ActionText::RichText.all.count }, -1 do
        message.update!(content: "")
      end
    end

    test "embed extraction" do
      blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
      message = Message.create!(subject: "Greetings", content: ActionText::Content.new("Hello world").append_attachables(blob))
      assert_equal "racecar.jpg", message.content.embeds.first.filename.to_s
    end
  end
end
