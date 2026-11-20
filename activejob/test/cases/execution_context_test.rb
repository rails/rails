# frozen_string_literal: true

require "helper"

class ExecutionContextTest < ActiveSupport::TestCase
  class ContextRecordingJob < ActiveJob::Base
    def perform(recorded)
      recorded << ActiveSupport::ExecutionContext.to_h[:job]
    end
  end

  class OuterJob < ActiveJob::Base
    def perform(recorded)
      recorded << ActiveSupport::ExecutionContext.to_h[:job]
      ContextRecordingJob.perform_now(recorded)
      recorded << ActiveSupport::ExecutionContext.to_h[:job]
    end
  end

  class RescuingJob < ActiveJob::Base
    rescue_from(RuntimeError) do
      arguments.first << ActiveSupport::ExecutionContext.to_h[:job]
    end

    def perform(recorded)
      raise "boom"
    end
  end

  class FailingJob < ActiveJob::Base
    def perform
      raise "boom"
    end
  end

  setup { ActiveSupport::ExecutionContext.clear }
  teardown { ActiveSupport::ExecutionContext.clear }

  test "perform_now sets the job in the execution context while performing" do
    recorded = []
    job = ContextRecordingJob.new(recorded)
    job.perform_now

    assert_equal [job], recorded
  end

  test "perform_now removes the job from the execution context after performing" do
    ContextRecordingJob.perform_now([])

    assert_nil ActiveSupport::ExecutionContext.to_h[:job]
  end

  test "perform_now removes the job from the execution context when the job raises" do
    assert_raises(RuntimeError) { FailingJob.perform_now }

    assert_nil ActiveSupport::ExecutionContext.to_h[:job]
  end

  test "perform_now keeps the job in the execution context while rescue handlers run" do
    recorded = []
    job = RescuingJob.new(recorded)
    job.perform_now

    assert_equal [job], recorded
    assert_nil ActiveSupport::ExecutionContext.to_h[:job]
  end

  test "perform_now restores the outer job after a nested inline job" do
    recorded = []
    outer = OuterJob.new(recorded)
    outer.perform_now

    assert_equal outer, recorded[0]
    assert_instance_of ContextRecordingJob, recorded[1]
    assert_equal outer, recorded[2]
    assert_nil ActiveSupport::ExecutionContext.to_h[:job]
  end
end
