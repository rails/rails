require_relative '../../test_helper'

class ActionMailbox::InboundEmail::IncinerationTest < ActiveSupport::TestCase
  test "incinerating 30 days after delivery" do
    freeze_time

    assert_enqueued_with job: ActionMailbox::InboundEmail::IncinerationJob, at: 30.days.from_now do
      create_inbound_email_from_fixture("welcome.eml").delivered!
    end
  end

  test "incinerating 30 days after bounce" do
    freeze_time

    assert_enqueued_with job: ActionMailbox::InboundEmail::IncinerationJob, at: 30.days.from_now do
      create_inbound_email_from_fixture("welcome.eml").bounced!
    end
  end

  test "incinerating 30 days after failure" do
    freeze_time

    assert_enqueued_with job: ActionMailbox::InboundEmail::IncinerationJob, at: 30.days.from_now do
      create_inbound_email_from_fixture("welcome.eml").failed!
    end
  end
end
