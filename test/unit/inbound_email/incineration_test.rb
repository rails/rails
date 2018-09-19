require_relative '../../test_helper'

class ActionMailroom::InboundEmail::IncinerationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "incinerate emails 30 days after they have been processed" do
    freeze_time

    assert_enqueued_with job: ActionMailroom::InboundEmail::IncinerationJob, at: 30.days.from_now do
      inbound_email = create_inbound_email("welcome.eml")
      inbound_email.delivered!
    end
  end
end
