# frozen_string_literal: true

require_relative '../../test_helper'

class ActionMailbox::InboundEmail::IncinerationTest < ActiveSupport::TestCase
  test 'incinerating 30 days after delivery' do
    freeze_time

    assert_enqueued_with job: ActionMailbox::IncinerationJob, at: 30.days.from_now do
      create_inbound_email_from_fixture('welcome.eml').delivered!
    end

    travel 30.days

    assert_difference -> { ActionMailbox::InboundEmail.count }, -1 do
      perform_enqueued_jobs only: ActionMailbox::IncinerationJob
    end
  end

  test 'incinerating 30 days after bounce' do
    freeze_time

    assert_enqueued_with job: ActionMailbox::IncinerationJob, at: 30.days.from_now do
      create_inbound_email_from_fixture('welcome.eml').bounced!
    end

    travel 30.days

    assert_difference -> { ActionMailbox::InboundEmail.count }, -1 do
      perform_enqueued_jobs only: ActionMailbox::IncinerationJob
    end
  end

  test 'incinerating 30 days after failure' do
    freeze_time

    assert_enqueued_with job: ActionMailbox::IncinerationJob, at: 30.days.from_now do
      create_inbound_email_from_fixture('welcome.eml').failed!
    end

    travel 30.days

    assert_difference -> { ActionMailbox::InboundEmail.count }, -1 do
      perform_enqueued_jobs only: ActionMailbox::IncinerationJob
    end
  end

  test 'skipping incineration' do
    original, ActionMailbox.incinerate = ActionMailbox.incinerate, false

    assert_no_enqueued_jobs only: ActionMailbox::IncinerationJob do
      create_inbound_email_from_fixture('welcome.eml').delivered!
    end
  ensure
    ActionMailbox.incinerate = original
  end
end
