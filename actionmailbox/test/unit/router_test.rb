# frozen_string_literal: true

require_relative "../test_helper"

class RootMailbox < ActionMailbox::Base
  def process
    $processed_by   = self.class.to_s
    $processed_mail = mail
  end
end

class FirstMailbox < RootMailbox
end

class SecondMailbox < RootMailbox
end

module Nested
  class FirstMailbox < RootMailbox
  end
end

class FirstMailboxAddress
  def match?(inbound_email)
    inbound_email.mail.to.include?("replies-class@example.com")
  end
end

module ActionMailbox
  class RouterTest < ActiveSupport::TestCase
    setup do
      @router = ActionMailbox::Router.new
      $processed_by = $processed_mail = nil
    end

    test "single string route" do
      @router.add_routes("first@example.com" => :first)

      inbound_email = create_inbound_email_from_mail(to: "first@example.com", subject: "This is a reply")
      @router.route inbound_email
      assert_equal "FirstMailbox", $processed_by
      assert_equal inbound_email.mail, $processed_mail
    end

    test "single string routing on cc" do
      @router.add_routes("first@example.com" => :first)

      inbound_email = create_inbound_email_from_mail(to: "someone@example.com", cc: "first@example.com", subject: "This is a reply")
      @router.route inbound_email
      assert_equal "FirstMailbox", $processed_by
      assert_equal inbound_email.mail, $processed_mail
    end

    test "single string routing on bcc" do
      @router.add_routes("first@example.com" => :first)

      inbound_email = create_inbound_email_from_mail(to: "someone@example.com", bcc: "first@example.com", subject: "This is a reply")
      @router.route inbound_email
      assert_equal "FirstMailbox", $processed_by
      assert_equal inbound_email.mail, $processed_mail
    end

    test "single string routing case-insensitively" do
      @router.add_routes("first@example.com" => :first)

      inbound_email = create_inbound_email_from_mail(to: "FIRST@example.com", subject: "This is a reply")
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

    test "single regexp route" do
      @router.add_routes(/replies-\w+@example.com/ => :first, "replies-nowhere@example.com" => :second)

      inbound_email = create_inbound_email_from_mail(to: "replies-okay@example.com", subject: "This is a reply")
      @router.route inbound_email
      assert_equal "FirstMailbox", $processed_by
    end

    test "single proc route" do
      @router.add_route \
        ->(inbound_email) { inbound_email.mail.to.include?("replies-proc@example.com") },
        to: :second

      @router.route create_inbound_email_from_mail(to: "replies-proc@example.com", subject: "This is a reply")
      assert_equal "SecondMailbox", $processed_by
    end

    test "address class route" do
      @router.add_route FirstMailboxAddress.new, to: :first
      @router.route create_inbound_email_from_mail(to: "replies-class@example.com", subject: "This is a reply")
      assert_equal "FirstMailbox", $processed_by
    end

    test "string route to nested mailbox" do
      @router.add_route "first@example.com", to: "nested/first"

      inbound_email = create_inbound_email_from_mail(to: "first@example.com", subject: "This is a reply")
      @router.route inbound_email
      assert_equal "Nested::FirstMailbox", $processed_by
    end

    test "all as the only route" do
      @router.add_route :all, to: :first
      @router.route create_inbound_email_from_mail(to: "replies-class@example.com", subject: "This is a reply")
      assert_equal "FirstMailbox", $processed_by
    end

    test "all as the second route" do
      @router.add_route FirstMailboxAddress.new, to: :first
      @router.add_route :all, to: :second

      @router.route create_inbound_email_from_mail(to: "replies-class@example.com", subject: "This is a reply")
      assert_equal "FirstMailbox", $processed_by

      @router.route create_inbound_email_from_mail(to: "elsewhere@example.com", subject: "This is a reply")
      assert_equal "SecondMailbox", $processed_by
    end

    test "missing route" do
      inbound_email = create_inbound_email_from_mail(to: "going-nowhere@example.com", subject: "This is a reply")
      assert_raises(ActionMailbox::Router::RoutingError) do
        @router.route inbound_email
      end
      assert_predicate inbound_email, :bounced?
    end

    test "invalid address" do
      error = assert_raises(ArgumentError) do
        @router.add_route Array.new, to: :first
      end
      assert_equal "Expected a Symbol, String, Regexp, Proc, or matchable, got []", error.message
    end

    test "single string mailbox_for" do
      @router.add_routes("first@example.com" => :first)

      inbound_email = create_inbound_email_from_mail(to: "first@example.com", subject: "This is a reply")
      assert_equal FirstMailbox, @router.mailbox_for(inbound_email)
    end

    test "mailbox_for with no matches" do
      @router.add_routes("first@example.com" => :first)

      inbound_email = create_inbound_email_from_mail(to: "second@example.com", subject: "This is a reply")
      assert_nil @router.mailbox_for(inbound_email)
    end
  end
end
