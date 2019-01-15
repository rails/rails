# frozen_string_literal: true

require_relative "../../test_helper"

class SuccessfulMailbox < ActionMailbox::Base
  def process
    $processed = mail.subject
  end
end

class UnsuccessfulMailbox < ActionMailbox::Base
  rescue_from(RuntimeError) { $processed = :failure }

  def process
    raise "No way!"
  end
end

class BouncingMailbox < ActionMailbox::Base
  def process
    $processed = :bounced
    bounced!
  end
end


class ActionMailbox::Base::StateTest < ActiveSupport::TestCase
  setup do
    $processed = false
    @inbound_email = create_inbound_email_from_mail \
      to: "replies@example.com", subject: "I was processed"
  end

  test "successful mailbox processing leaves inbound email in delivered state" do
    SuccessfulMailbox.receive @inbound_email
    assert @inbound_email.delivered?
    assert_equal "I was processed", $processed
  end

  test "unsuccessful mailbox processing leaves inbound email in failed state" do
    UnsuccessfulMailbox.receive @inbound_email
    assert @inbound_email.failed?
    assert_equal :failure, $processed
  end

  test "bounced inbound emails are not delivered" do
    BouncingMailbox.receive @inbound_email
    assert @inbound_email.bounced?
    assert_equal :bounced, $processed
  end
end
