# frozen_string_literal: true

require_relative "../../test_helper"

class RepliesMailbox < ActionMailbox::Base
end

class ActionMailbox::Base::NotificationsTest < ActiveSupport::TestCase
  test "instruments processing" do
    mailbox = RepliesMailbox.new(create_inbound_email_from_fixture("welcome.eml"))
    expected_payload = {
      mailbox:,
      inbound_email: {
        id: 1,
        message_id: "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com",
        status: "processing"
      }
    }

    assert_notifications_count("process.action_mailbox", 1) do
      assert_notification("process.action_mailbox", expected_payload) do
        mailbox.perform_processing
      end
    end
  end
end
