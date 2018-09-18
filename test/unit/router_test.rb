require_relative '../test_helper'

class RepliesMailbox < ActionMailroom::Mailbox
  def process
    $processed = mail.subject
  end
end

module ActionMailroom
  class RouterTest < ActiveSupport::TestCase
    setup do
      @router = ActionMailroom::Router.new('replies@example.com' => :replies)
      $processed = false
    end

    test "routed to mailbox" do
      @router.route create_inbound_email("welcome.eml")
      assert_equal "Discussion: Let's debate these attachments", $processed
    end
  end
end
