# frozen_string_literal: true

require_relative "../../test_helper"

class ActionMailbox::InboundEmail::MessageIdTest < ActiveSupport::TestCase
  test "message id is extracted from raw email" do
    inbound_email = create_inbound_email_from_fixture("welcome.eml")
    assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
  end

  test "message id is generated if its missing" do
    inbound_email = create_inbound_email_from_source "Date: Fri, 28 Sep 2018 11:08:55 -0700\r\nTo: a@example.com\r\nMime-Version: 1.0\r\nContent-Type: text/plain\r\nContent-Transfer-Encoding: 7bit\r\n\r\nHello!"
    assert_not_nil inbound_email.message_id
  end

  test "duplicate delivery is a no-op and does not leak an orphaned raw_email blob" do
    source = "Message-ID: <dup@example.com>\r\nFrom: a@example.com\r\nTo: b@example.com\r\nSubject: hello\r\n\r\nbody"

    ActionMailbox::InboundEmail.create_and_extract_message_id!(source)

    assert_no_difference -> { ActiveStorage::Blob.count } do
      assert_nil ActionMailbox::InboundEmail.create_and_extract_message_id!(source)
    end
  end
end
