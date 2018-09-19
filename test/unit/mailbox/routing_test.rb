require_relative '../../test_helper'

class ApplicationMailbox < ActionMailroom::Mailbox
  routing "replies@example.com" => :replies
end

class RepliesMailbox < ActionMailroom::Mailbox
  def process
    $processed = mail.subject
  end
end

class ActionMailroom::Mailbox::RoutingTest < ActiveSupport::TestCase
  setup do
    $processed = false
    @inbound_email = create_inbound_email("welcome.eml")
  end

  test "string routing" do
    ApplicationMailbox.route @inbound_email
    assert_equal "Discussion: Let's debate these attachments", $processed
  end

  test "delayed routing" do
    perform_enqueued_jobs only: ActionMailroom::DeliverInboundEmailToMailroomJob do
      another_inbound_email = create_inbound_email("welcome.eml", status: :pending)
      assert_equal "Discussion: Let's debate these attachments", $processed
    end
  end
end
