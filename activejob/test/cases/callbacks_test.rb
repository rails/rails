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

  test "enqueue callbacks" do
    enqueued_callback_job = CallbackJob.perform_later
    assert "CallbackJob ran before_enqueue".in? enqueued_callback_job.history
    assert "CallbackJob ran after_enqueue".in? enqueued_callback_job.history
    assert "CallbackJob ran around_enqueue_start".in? enqueued_callback_job.history
    assert "CallbackJob ran around_enqueue_stop".in? enqueued_callback_job.history
  end

  test "#enqueue returns false when before_enqueue aborts callback chain and return_false_on_aborted_enqueue = true" do
    prev = ActiveJob::Base.return_false_on_aborted_enqueue
    ActiveJob::Base.return_false_on_aborted_enqueue = true
    assert_equal false, AbortBeforeEnqueueJob.new.enqueue
  ensure
    ActiveJob::Base.return_false_on_aborted_enqueue = prev
  end

  test "#enqueue returns self when before_enqueue aborts callback chain and return_false_on_aborted_enqueue = false" do
    prev = ActiveJob::Base.return_false_on_aborted_enqueue
    ActiveJob::Base.return_false_on_aborted_enqueue = false
    job = AbortBeforeEnqueueJob.new
    assert_deprecated do
      assert_equal job, job.enqueue
    end
  ensure
    ActiveJob::Base.return_false_on_aborted_enqueue = prev
  end

  test "#enqueue does not run after_enqueue callbacks when skip_after_callbacks_if_terminated is true" do
    prev = ActiveJob::Base.skip_after_callbacks_if_terminated
    ActiveJob::Base.skip_after_callbacks_if_terminated = true
    reload_job
    job = AbortBeforeEnqueueJob.new
    job.enqueue

    assert_nil(job.flag)
  ensure
    ActiveJob::Base.skip_after_callbacks_if_terminated = prev
  end

  test "#enqueue does run after_enqueue callbacks when skip_after_callbacks_if_terminated is false" do
    prev = ActiveJob::Base.skip_after_callbacks_if_terminated
    ActiveJob::Base.skip_after_callbacks_if_terminated = false
    reload_job
    job = AbortBeforeEnqueueJob.new
    job.enqueue

    assert_equal("after_enqueue", job.flag)
  ensure
    ActiveJob::Base.skip_after_callbacks_if_terminated = prev
  end

  test "#perform does not run after_perform callbacks when skip_after_callbacks_if_terminated is true" do
    prev = ActiveJob::Base.skip_after_callbacks_if_terminated
    ActiveJob::Base.skip_after_callbacks_if_terminated = true
    reload_job
    job = AbortBeforeEnqueueJob.new
    job.perform_now

    assert_nil(job.flag)
  ensure
    ActiveJob::Base.skip_after_callbacks_if_terminated = prev
  end

  test "#perform does run after_perform callbacks when skip_after_callbacks_if_terminated is false" do
    prev = ActiveJob::Base.skip_after_callbacks_if_terminated
    ActiveJob::Base.skip_after_callbacks_if_terminated = false
    reload_job
    job = AbortBeforeEnqueueJob.new
    job.perform_now

    assert_equal("after_perform", job.flag)
  ensure
    ActiveJob::Base.skip_after_callbacks_if_terminated = prev
  end

  test "#enqueue returns self when the job was enqueued" do
    job = CallbackJob.new
    assert_equal job, job.enqueue
  end

  private
    def reload_job
      Object.send(:remove_const, :AbortBeforeEnqueueJob)
      $LOADED_FEATURES.delete($LOADED_FEATURES.grep(%r{jobs/abort_before_enqueue_job}).first)
      require "jobs/abort_before_enqueue_job"
    end
end
