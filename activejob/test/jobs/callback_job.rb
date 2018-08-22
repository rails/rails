# frozen_string_literal: true

class CallbackRetryError < StandardError; end
class CallbackStopRetryError < StandardError; end
class CallbackDiscardError < StandardError; end

class CallbackJob < ActiveJob::Base
  before_perform ->(job) { job.history << "CallbackJob ran before_perform" }
  after_perform ->(job) { job.history << "CallbackJob ran after_perform" }

  before_enqueue ->(job) { job.history << "CallbackJob ran before_enqueue" }
  after_enqueue ->(job) { job.history << "CallbackJob ran after_enqueue" }

  before_retry ->(job) { job.history << "CallbackJob ran before_retry" }
  after_retry ->(job) { job.history << "CallbackJob ran after_retry" }

  before_retry_stopped ->(job) { job.history << "CallbackJob ran before_retry_stopped" }
  after_retry_stopped ->(job) { job.history << "CallbackJob ran after_retry_stopped" }

  before_discard ->(job) { job.history << "CallbackJob ran before_discard" }
  after_discard ->(job) { job.history << "CallbackJob ran after_discard" }

  around_perform do |job, block|
    job.history << "CallbackJob ran around_perform_start"
    block.call
    job.history << "CallbackJob ran around_perform_stop"
  end

  around_enqueue do |job, block|
    job.history << "CallbackJob ran around_enqueue_start"
    block.call
    job.history << "CallbackJob ran around_enqueue_stop"
  end

  around_retry do |job, block|
    job.history << "CallbackJob ran around_retry_start"
    block.call
    job.history << "CallbackJob ran around_retry_stop"
  end

  around_retry_stopped do |job, block|
    job.history << "CallbackJob ran around_retry_stopped_start"
    block.call
    job.history << "CallbackJob ran around_retry_stopped_stop"
  end

  around_discard do |job, block|
    job.history << "CallbackJob ran around_discard_start"
    block.call
    job.history << "CallbackJob ran around_discard_stop"
  end

  retry_on CallbackRetryError, attempts: 2 do |job, error|
    # Nothing
  end

  retry_on CallbackStopRetryError, attempts: 1 do |job, error|
    # Nothing
  end

  discard_on CallbackDiscardError

  def perform(action = :none)
    case action
    when :retry
      raise CallbackRetryError
    when :retry_stopped
      raise CallbackStopRetryError
    when :discard
      raise CallbackDiscardError
    else
      # Nothing
    end
  end

  def history
    @history ||= []
  end
end
