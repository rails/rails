# frozen_string_literal: true

require_relative '../../test_helper'

class ApplicationMailbox < ActionMailbox::Base
  routing 'replies@example.com' => :replies
end

class RepliesMailbox < ActionMailbox::Base
  def process
    $processed = mail.subject
  end
end

class ActionMailbox::Base::RoutingTest < ActiveSupport::TestCase
  setup do
    $processed = false
  end

  test 'string routing' do
    ApplicationMailbox.route create_inbound_email_from_fixture('welcome.eml')
    assert_equal "Discussion: Let's debate these attachments", $processed
  end

  test 'delayed routing' do
    perform_enqueued_jobs only: ActionMailbox::RoutingJob do
      create_inbound_email_from_fixture 'welcome.eml', status: :pending
      assert_equal "Discussion: Let's debate these attachments", $processed
    end
  end

  test 'mailbox_for' do
    inbound_email = create_inbound_email_from_fixture 'welcome.eml', status: :pending
    assert_equal RepliesMailbox, ApplicationMailbox.mailbox_for(inbound_email)
  end
end
