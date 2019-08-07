# frozen_string_literal: true

require_relative "../test_helper"

module ActionMailbox
  class TestHelperTest < ActiveSupport::TestCase
    test "multi-part mail can be built in tests using a block" do
      inbound_email = create_inbound_email_from_mail do
        to "test@example.com"
        from "hello@example.com"

        text_part do
          body "Hello, world"
        end

        html_part do
          body "<h1>Hello, world</h1>"
        end
      end

      mail = inbound_email.mail

      assert_equal mail.parts.length, 2
      assert_equal mail.text_part.to_s, <<~TEXT.chomp
        Content-Type: text/plain;\r
         charset=UTF-8\r
        Content-Transfer-Encoding: 7bit\r
        \r
        Hello, world
      TEXT
      assert_equal mail.html_part.to_s, <<~HTML.chomp
        Content-Type: text/html;\r
         charset=UTF-8\r
        Content-Transfer-Encoding: 7bit\r
        \r
        <h1>Hello, world</h1>
      HTML
    end
  end
end
