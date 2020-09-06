# frozen_string_literal: true

require_relative '../test_helper'

module ActionMailbox
  class InboundEmailTest < ActiveSupport::TestCase
    test 'mail provides the parsed source' do
      assert_equal "Discussion: Let's debate these attachments", create_inbound_email_from_fixture('welcome.eml').mail.subject
    end

    test 'source returns the contents of the raw email' do
      assert_equal file_fixture('welcome.eml').read, create_inbound_email_from_fixture('welcome.eml').source
    end

    test 'email with message id is processed only once when received multiple times' do
      mail = Mail.from_source(file_fixture('welcome.eml').read)
      assert mail.message_id

      inbound_email_1 = create_inbound_email_from_source(mail.to_s)
      assert inbound_email_1

      inbound_email_2 = create_inbound_email_from_source(mail.to_s)
      assert_nil inbound_email_2
    end

    test 'email with missing message id is processed only once when received multiple times' do
      mail = Mail.from_source("Date: Fri, 28 Sep 2018 11:08:55 -0700\r\nTo: a@example.com\r\nMime-Version: 1.0\r\nContent-Type: text/plain\r\nContent-Transfer-Encoding: 7bit\r\n\r\nHello!")
      assert_nil mail.message_id

      inbound_email_1 = create_inbound_email_from_source(mail.to_s)
      assert inbound_email_1

      inbound_email_2 = create_inbound_email_from_source(mail.to_s)
      assert_nil inbound_email_2
    end
  end
end
