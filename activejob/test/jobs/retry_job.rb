require_relative '../support/job_buffer'
require 'active_support/core_ext/integer/inflections'

class SeriousError < StandardError; end
class VerySeriousError < StandardError; end
class NotSeriousError < StandardError; end

class RetryJob < ActiveJob::Base
  retry_on SeriousError
  retry_on VerySeriousError, wait: 1.second, attempts: 10
  discard_on NotSeriousError

  def perform(raising, attempts)
    if executions < attempts
      JobBuffer.add("Raised #{raising} for the #{executions.ordinalize} time")
      raise raising.constantize
    else
      JobBuffer.add("Successfully completed job")
    end
  end
end
