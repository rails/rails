require_relative '../../test_helper'

class ActionMailbox::InboundEmail::IncinerationTest < ActiveSupport::TestCase
  test "incinerate emails 30 days after they have been processed" do
    freeze_time

    assert_enqueued_with job: ActionMailbox::InboundEmail::IncinerationJob, at: 30.days.from_now do
      create_inbound_email_from_fixture("welcome.eml").delivered!
    end
  end
end
