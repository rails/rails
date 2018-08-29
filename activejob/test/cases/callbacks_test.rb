# frozen_string_literal: true

require "helper"
require "jobs/callback_job"

require "active_support/core_ext/object/inclusion"

class CallbacksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "retry callbacks" do
    retry_callback_job = CallbackJob.new(:retry)
    retry_callback_job.perform_now
    assert "CallbackJob ran before_retry".in? retry_callback_job.history
    assert "CallbackJob ran after_retry".in? retry_callback_job.history
    assert "CallbackJob ran around_retry_start".in? retry_callback_job.history
    assert "CallbackJob ran around_retry_stop".in? retry_callback_job.history
  end

  test "retry_stopped callbacks" do
    retry_callback_job = CallbackJob.new(:retry_stopped)
    retry_callback_job.perform_now

    assert "CallbackJob ran before_retry_stopped".in? retry_callback_job.history
    assert "CallbackJob ran after_retry_stopped".in? retry_callback_job.history
    assert "CallbackJob ran around_retry_stopped_start".in? retry_callback_job.history
    assert "CallbackJob ran around_retry_stopped_stop".in? retry_callback_job.history
  end

  test "discard callbacks" do
    discard_callback_job = CallbackJob.new(:discard)
    discard_callback_job.perform_now
    assert "CallbackJob ran before_discard".in? discard_callback_job.history
    assert "CallbackJob ran after_discard".in? discard_callback_job.history
    assert "CallbackJob ran around_discard_start".in? discard_callback_job.history
    assert "CallbackJob ran around_discard_stop".in? discard_callback_job.history
  end
end
