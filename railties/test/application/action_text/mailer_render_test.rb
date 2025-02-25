# frozen_string_literal: true

require "isolation/abstract_unit"
require "application/action_text_integration_test_helper"

module ApplicationTests
  class ActionText::MailerRenderTest < ActionMailer::TestCase
    include ActiveSupport::Testing::Isolation

    test "uses default_url_options" do
      app("development")
      Rails.application.reload_routes_unless_loaded

      original_default_url_options = ActionMailer::Base.default_url_options
      ActionMailer::Base.default_url_options = { host: "hoost" }

      blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      message = Message.new(content: ActionText::Content.new.append_attachables(blob))

      msg = MessagesMailer.with(recipient: "test", message: message).notification
      msg.deliver_now

      assert_select_email do
        assert_select "#message-content img" do |imgs|
          imgs.each { |img| assert_match %r"//hoost/", img["src"] }
        end
      end
    ensure
      ActionMailer::Base.default_url_options = original_default_url_options
    end
  end
end
