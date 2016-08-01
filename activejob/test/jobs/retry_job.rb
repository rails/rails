require_relative '../support/job_buffer'
require 'active_support/core_ext/integer/inflections'

class DefaultsError < StandardError; end
class ShortWaitTenAttemptsError < StandardError; end
class DiscardableError < StandardError; end

class RetryJob < ActiveJob::Base
  retry_on DefaultsError
  retry_on ShortWaitTenAttemptsError, wait: 1.second, attempts: 10
  discard_on DiscardableError

  def perform(raising, attempts)
    if executions < attempts
      JobBuffer.add("Raised #{raising} for the #{executions.ordinalize} time")
      raise raising.constantize
    else
      JobBuffer.add("Successfully completed job")
    end
  end
end
