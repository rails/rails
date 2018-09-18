require_relative '../test_helper'

class RepliesMailbox < ActionMailroom::Mailbox
  def process
    $processed = true
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
      assert $processed
    end
  end
end
