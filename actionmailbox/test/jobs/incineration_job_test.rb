# frozen_string_literal: true

require "test_helper"

class ActionMailbox::IncinerationJobTest < ActiveJob::TestCase
  setup { @inbound_email = create_inbound_email_from_fixture("welcome.eml") }

  test "ignoring a missing inbound email" do
    old_logger = ActiveJob::Base.logger
    output = StringIO.new
    ActiveJob::Base.logger = ActiveSupport::Logger.new(output)
    @inbound_email.destroy!

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActionMailbox::IncinerationJob.perform_later @inbound_email
      end
    end

    assert_match "Couldn't find ActionMailbox::InboundEmail with 'id'", output.string
  ensure
    ActiveJob::Base.logger = old_logger
  end
end
