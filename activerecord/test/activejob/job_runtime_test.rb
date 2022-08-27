# frozen_string_literal: true

require "activejob/helper"
require "active_record/railties/job_runtime"

class JobRuntimeTest < ActiveSupport::TestCase
  class TestJob < ActiveJob::Base
    include ActiveRecord::Railties::JobRuntime

    def perform(*)
      ActiveRecord::LogSubscriber.runtime += 42
    end
  end

  test "job notification payload includes db_runtime" do
    ActiveRecord::LogSubscriber.runtime = 0

    assert_equal 42, notification_payload[:db_runtime]
  end

  test "db_runtime tracks database runtime for job only" do
    ActiveRecord::LogSubscriber.runtime = 100

    assert_equal 42, notification_payload[:db_runtime]
    assert_equal 142, ActiveRecord::LogSubscriber.runtime
  end

  private
    def notification_payload
      payload = nil
      subscriber = ActiveSupport::Notifications.subscribe("perform.active_job") do |*, _payload|
        payload = _payload
      end

      TestJob.perform_now

      ActiveSupport::Notifications.unsubscribe(subscriber)

      payload
    end
end
