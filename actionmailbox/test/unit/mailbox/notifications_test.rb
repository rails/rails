# frozen_string_literal: true

require_relative "../../test_helper"

class RepliesMailbox < ActionMailbox::Base
end

class ActionMailbox::Base::NotificationsTest < ActiveSupport::TestCase
  test "instruments processing" do
    events = []
    ActiveSupport::Notifications.subscribe("process.action_mailbox") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    mailbox = RepliesMailbox.new(create_inbound_email_from_fixture("welcome.eml"))
    mailbox.perform_processing

    assert_equal 1, events.length
    assert_equal "process.action_mailbox", events[0].name
    assert_equal(
      {
        mailbox: mailbox,
        inbound_email: {
          id: 1,
          message_id: "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com",
          status: "processing"
        }
      },
      events[0].payload
    )
  ensure
    ActiveSupport::Notifications.unsubscribe("process.action_mailbox")
  end
end
