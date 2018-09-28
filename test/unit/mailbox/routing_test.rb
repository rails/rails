require_relative '../../test_helper'

class ApplicationMailbox < ActionMailbox::Base
  routing "replies@example.com" => :replies
end

class RepliesMailbox < ActionMailbox::Base
  def process
    $processed = mail.subject
  end
end

class ActionMailbox::Base::RoutingTest < ActiveSupport::TestCase
  setup do
    $processed = false
    @inbound_email = create_inbound_email_from_fixture("welcome.eml")
  end

  test "string routing" do
    ApplicationMailbox.route @inbound_email
    assert_equal "Discussion: Let's debate these attachments", $processed
  end

  test "delayed routing" do
    perform_enqueued_jobs only: ActionMailbox::RoutingJob do
      another_inbound_email = create_inbound_email_from_fixture("welcome.eml", status: :pending)
      assert_equal "Discussion: Let's debate these attachments", $processed
    end
  end
end
