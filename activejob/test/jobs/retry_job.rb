# frozen_string_literal: true

require_relative "../support/job_buffer"
require "active_support/core_ext/integer/inflections"

class DefaultsError < StandardError; end
class DisabledJitterError < StandardError; end
class ZeroJitterError < StandardError; end
class FirstRetryableErrorOfTwo < StandardError; end
class SecondRetryableErrorOfTwo < StandardError; end
class LongWaitError < StandardError; end
class ShortWaitTenAttemptsError < StandardError; end
class ExponentialWaitTenAttemptsError < StandardError; end
class CustomWaitTenAttemptsError < StandardError; end
class CustomCatchError < StandardError; end
class DiscardableError < StandardError; end
class FirstDiscardableErrorOfTwo < StandardError; end
class SecondDiscardableErrorOfTwo < StandardError; end
class CustomDiscardableError < StandardError; end

class RetryJob < ActiveJob::Base
  retry_on DefaultsError
  retry_on DisabledJitterError, jitter: nil
  retry_on ZeroJitterError, jitter: 0.0
  retry_on FirstRetryableErrorOfTwo, SecondRetryableErrorOfTwo, attempts: 4
  retry_on LongWaitError, wait: 1.hour, attempts: 10
  retry_on ShortWaitTenAttemptsError, wait: 1.second, attempts: 10
  retry_on ExponentialWaitTenAttemptsError, wait: :exponentially_longer, attempts: 10
  retry_on CustomWaitTenAttemptsError, wait: ->(executions) { executions * 2 }, attempts: 10
  retry_on(CustomCatchError) { |job, error| JobBuffer.add("Dealt with a job that failed to retry in a custom way after #{job.arguments.second} attempts. Message: #{error.message}") }
  retry_on(ActiveJob::DeserializationError) { |job, error| JobBuffer.add("Raised #{error.class} for the #{job.executions} time") }

  discard_on DiscardableError
  discard_on FirstDiscardableErrorOfTwo, SecondDiscardableErrorOfTwo
  discard_on(CustomDiscardableError) { |job, error| JobBuffer.add("Dealt with a job that was discarded in a custom way. Message: #{error.message}") }

  before_enqueue do |job|
    if job.arguments.include?(:log_scheduled_at) && job.scheduled_at
      JobBuffer.add("Next execution scheduled at #{job.scheduled_at}")
    end
  end

  def perform(raising, attempts, *)
    raising = raising.shift if raising.is_a?(Array)
    if raising && executions < attempts
      JobBuffer.add("Raised #{raising} for the #{executions.ordinalize} time")
      raise raising.constantize
    else
      JobBuffer.add("Successfully completed job")
    end
  end
end
