# frozen_string_literal: true

require_relative "../support/job_buffer"
require "active_support/core_ext/integer/inflections"

class DefaultsError < StandardError; end
class LongWaitError < StandardError; end
class ShortWaitTenAttemptsError < StandardError; end
class ExponentialWaitTenAttemptsError < StandardError; end
class CustomWaitTenAttemptsError < StandardError; end
class CustomCatchError < StandardError; end
class DiscardableError < StandardError; end
class CustomDiscardableError < StandardError; end

class RetryJob < ActiveJob::Base
  retry_on DefaultsError
  retry_on LongWaitError, wait: 1.hour, attempts: 10
  retry_on ShortWaitTenAttemptsError, wait: 1.second, attempts: 10
  retry_on ExponentialWaitTenAttemptsError, wait: :exponentially_longer, attempts: 10
  retry_on CustomWaitTenAttemptsError, wait: ->(executions) { executions * 2 }, attempts: 10
  retry_on(CustomCatchError) { |job, error| JobBuffer.add("Dealt with a job that failed to retry in a custom way after #{job.arguments.second} attempts. Message: #{error.message}") }
  discard_on DiscardableError
  discard_on(CustomDiscardableError) { |job, error| JobBuffer.add("Dealt with a job that was discarded in a custom way. Message: #{error.message}") }

  def perform(raising, attempts)
    if executions < attempts
      JobBuffer.add("Raised #{raising} for the #{executions.ordinalize} time")
      raise raising.constantize
    else
      JobBuffer.add("Successfully completed job")
    end
  end
end
