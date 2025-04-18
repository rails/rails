# frozen_string_literal: true

require_relative "../../test_helper"

class BouncingWithReplyMailbox < ActionMailbox::Base
  def process
    bounce_with BounceMailer.bounce(to: mail.from)
  end
end

class BouncingWithImmediateReplyMailbox < ActionMailbox::Base
  def process
    bounce_now_with BounceMailer.bounce(to: mail.from)
  end
end

class ActionMailbox::Base::BouncingTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @inbound_email = create_inbound_email_from_mail \
      from: "sender@example.com", to: "replies@example.com", subject: "Bounce me"
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end

  test "bouncing with a reply" do
    perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      BouncingWithReplyMailbox.receive @inbound_email
    end

    assert_predicate @inbound_email, :bounced?
    assert_emails 1

    mail = ActionMailer::Base.deliveries.last
    assert_equal %w[ sender@example.com ], mail.to
    assert_equal "Your email was not delivered", mail.subject
  end

  test "bouncing now with a reply" do
    assert_no_enqueued_emails do
      BouncingWithImmediateReplyMailbox.receive @inbound_email
    end

    assert_predicate @inbound_email, :bounced?
    assert_emails 1

    mail = ActionMailer::Base.deliveries.last
    assert_equal %w[ sender@example.com ], mail.to
    assert_equal "Your email was not delivered", mail.subject
  end
end
