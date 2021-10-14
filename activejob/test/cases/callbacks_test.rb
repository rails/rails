# frozen_string_literal: true

require "helper"
require "jobs/callback_job"
require "jobs/abort_before_enqueue_job"

require "active_support/core_ext/object/inclusion"

class CallbacksTest < ActiveSupport::TestCase
  test "perform callbacks" do
    performed_callback_job = CallbackJob.new("A-JOB-ID")
    performed_callback_job.perform_now
    assert "CallbackJob ran before_perform".in? performed_callback_job.history
    assert "CallbackJob ran after_perform".in? performed_callback_job.history
    assert "CallbackJob ran around_perform_start".in? performed_callback_job.history
    assert "CallbackJob ran around_perform_stop".in? performed_callback_job.history
  end

  test "perform return value" do
    job = Class.new(ActiveJob::Base) do
      def perform
        123
      end
    end

    assert_equal(123, job.perform_now)
  end

  test "perform around_callbacks return value" do
    value = nil

    Class.new(ActiveJob::Base) do
      around_perform do |_, block|
        value = block.call
      end

      def perform
        123
      end
    end.perform_now

    assert_equal(123, value)
  end

  test "enqueue callbacks" do
    enqueued_callback_job = CallbackJob.perform_later
    assert "CallbackJob ran before_enqueue".in? enqueued_callback_job.history
    assert "CallbackJob ran after_enqueue".in? enqueued_callback_job.history
    assert "CallbackJob ran around_enqueue_start".in? enqueued_callback_job.history
    assert "CallbackJob ran around_enqueue_stop".in? enqueued_callback_job.history
  end

  test "#enqueue returns false when before_enqueue aborts callback chain" do
    assert_equal false, AbortBeforeEnqueueJob.new.enqueue
  end

  test "#enqueue does not run after_enqueue callbacks when previous callbacks aborted" do
    job = AbortBeforeEnqueueJob.new
    ActiveSupport::Deprecation.silence do
      job.enqueue
    end

    assert_nil(job.flag)
  end

  test "#perform does not run after_perform callbacks when swhen previous callbacks aborted" do
    job = AbortBeforeEnqueueJob.new
    job.perform_now

    assert_nil(job.flag)
  end

  test "#enqueue returns self when the job was enqueued" do
    job = CallbackJob.new
    assert_equal job, job.enqueue
  end
end
