# frozen_string_literal: true

require_relative '../../test_helper'

class BouncingWithReplyMailbox < ActionMailbox::Base
  def process
    bounce_with BounceMailer.bounce(to: mail.from)
  end
end

class ActionMailbox::Base::BouncingTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @inbound_email = create_inbound_email_from_mail \
      from: 'sender@example.com', to: 'replies@example.com', subject: 'Bounce me'
  end

  test 'bouncing with a reply' do
    perform_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      BouncingWithReplyMailbox.receive @inbound_email
    end

    assert @inbound_email.bounced?
    assert_emails 1

    mail = ActionMailer::Base.deliveries.last
    assert_equal %w[ sender@example.com ], mail.to
    assert_equal 'Your email was not delivered', mail.subject
  end
end
