require_relative '../../test_helper'

class ActionMailroom::InboundEmail::RoutingTest < ActiveSupport::TestCase
  test "pending emails are delivered to the mailroom" do
    assert_enqueued_jobs 1, only: ActionMailroom::RoutingJob do
      create_inbound_email("welcome.eml", status: :pending)
    end
  end
end
