require_relative '../../test_helper'

class ActionMailbox::InboundEmail::MessageIdTest < ActiveSupport::TestCase
  test "message id is extracted from raw email" do
    inbound_email = create_inbound_email_from_fixture("welcome.eml")
    assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
  end

  test "message id is generated if its missing" do
    source_without_message_id = "Date: Fri, 28 Sep 2018 11:08:55 -0700\r\nTo: a@example.com\r\nMime-Version: 1.0\r\nContent-Type: text/plain\r\nContent-Transfer-Encoding: 7bit\r\n\r\nHello!"
    inbound_email = create_inbound_email Tempfile.new.tap { |raw_email| raw_email.write source_without_message_id }

    assert_not_nil inbound_email.message_id
  end
end
