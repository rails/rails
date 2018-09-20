require_relative '../../test_helper'

class SuccessfulMailbox < ActionMailroom::Mailbox
  def process
    $processed = mail.subject
  end
end

class UnsuccessfulMailbox < ActionMailroom::Mailbox
  rescue_from(RuntimeError) { $processed = :failure }

  def process
    raise "No way!"
  end
end

class ActionMailroom::Mailbox::StateTest < ActiveSupport::TestCase
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
end
