# frozen_string_literal: true

require "activejob/helper"
require "active_record/railties/job_runtime"

class JobRuntimeTest < ActiveSupport::TestCase
  class TestJob < ActiveJob::Base
    include ActiveRecord::Railties::JobRuntime

    def perform(*)
      ActiveRecord::RuntimeRegistry.sql_runtime += 42.0
    end
  end

  test "job notification payload includes db_runtime" do
    ActiveRecord::RuntimeRegistry.sql_runtime = 0.0

    event = capture_notifications("perform.active_job") { TestJob.perform_now }.first

    assert_equal 42, event.payload[:db_runtime]
  end

  test "db_runtime tracks database runtime for job only" do
    ActiveRecord::RuntimeRegistry.sql_runtime = 100.0

    event = capture_notifications("perform.active_job") { TestJob.perform_now }.first

    assert_equal 42.0, event.payload[:db_runtime]
    assert_equal 142.0, ActiveRecord::RuntimeRegistry.sql_runtime
  end
end
