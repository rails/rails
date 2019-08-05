# frozen_string_literal: true

require_relative "../test_helper"

module ActionMailbox
  class InboundEmailTest < ActiveSupport::TestCase
    test "mail provides the parsed source" do
      assert_equal "Discussion: Let's debate these attachments", create_inbound_email_from_fixture("welcome.eml").mail.subject
    end

    test "source returns the contents of the raw email" do
      assert_equal file_fixture("welcome.eml").read, create_inbound_email_from_fixture("welcome.eml").source
    end

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

    test "email with message id is processed only once when received multiple times" do
      mail = Mail.from_source(file_fixture("welcome.eml").read)
      assert mail.message_id

      inbound_email_1 = create_inbound_email_from_source(mail.to_s)
      assert inbound_email_1

      inbound_email_2 = create_inbound_email_from_source(mail.to_s)
      assert_nil inbound_email_2
    end

    test "email with missing message id is processed only once when received multiple times" do
      mail = Mail.from_source("Date: Fri, 28 Sep 2018 11:08:55 -0700\r\nTo: a@example.com\r\nMime-Version: 1.0\r\nContent-Type: text/plain\r\nContent-Transfer-Encoding: 7bit\r\n\r\nHello!")
      assert_nil mail.message_id

      inbound_email_1 = create_inbound_email_from_source(mail.to_s)
      assert inbound_email_1

      inbound_email_2 = create_inbound_email_from_source(mail.to_s)
      assert_nil inbound_email_2
    end
  end
end
