require_relative '../test_helper'

class RepliesMailbox < ActionMailroom::Mailbox
  def process
    $processed = mail.subject
  end
end

module ActionMailroom
  class RouterTest < ActiveSupport::TestCase
    setup do
      @router = ActionMailroom::Router.new
      @router.add_routes('replies@example.com' => :replies)
      $processed = false
    end

    test "routed to mailbox" do
      @router.route \
        create_inbound_email_from_mail(to: "replies@example.com", subject: "This is a reply")

      assert_equal "This is a reply", $processed
    end
  end
end
