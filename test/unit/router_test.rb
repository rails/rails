require_relative '../test_helper'

class RootMailbox < ActionMailroom::Mailbox
  def process
    $processed_by   = self.class.to_s
    $processed_mail = mail
  end
end

class FirstMailbox < RootMailbox
end

class SecondMailbox < RootMailbox
end

module ActionMailroom
  class RouterTest < ActiveSupport::TestCase
    setup do
      @router = ActionMailroom::Router.new
      $processed_by = $processed_mail = nil
    end

    test "single string route" do
      @router.add_routes("first@example.com" => :first)

      inbound_email = create_inbound_email_from_mail(to: "first@example.com", subject: "This is a reply")
      @router.route inbound_email
      assert_equal "FirstMailbox", $processed_by
      assert_equal inbound_email.mail, $processed_mail      
    end

    test "multiple string routes" do
      @router.add_routes("first@example.com" => :first, "second@example.com" => :second)

      inbound_email = create_inbound_email_from_mail(to: "first@example.com", subject: "This is a reply")
      @router.route inbound_email
      assert_equal "FirstMailbox", $processed_by
      assert_equal inbound_email.mail, $processed_mail

      inbound_email = create_inbound_email_from_mail(to: "second@example.com", subject: "This is a reply")
      @router.route inbound_email
      assert_equal "SecondMailbox", $processed_by
      assert_equal inbound_email.mail, $processed_mail
    end
  end
end
