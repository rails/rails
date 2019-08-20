# frozen_string_literal: true

require "test_helper"

class ActionMailbox::IncinerationJobTest < ActiveJob::TestCase
  setup { @inbound_email = receive_inbound_email_from_fixture("welcome.eml") }

  test "ignoring a missing inbound email" do
    @inbound_email.destroy!

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActionMailbox::IncinerationJob.perform_later @inbound_email
      end
    end
  end
end
