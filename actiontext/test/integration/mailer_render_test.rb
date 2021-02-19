# frozen_string_literal: true

require "test_helper"

class ActionText::MailerRenderTest < ActionMailer::TestCase
  test "uses default_url_options" do
    original_default_url_options = ActionMailer::Base.default_url_options
    ActionMailer::Base.default_url_options = { host: "hoost" }

    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    message = Message.new(content: ActionText::Content.new.append_attachables(blob))

    MessagesMailer.with(recipient: "test", message: message).notification.deliver_now

    assert_dom_email do
      assert_dom "#message-content img" do |imgs|
        imgs.each { |img| assert_match %r"//hoost/", img["src"] }
      end
    end
  ensure
    ActionMailer::Base.default_url_options = original_default_url_options
  end
end
