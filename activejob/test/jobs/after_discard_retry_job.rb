# frozen_string_literal: true

require_relative "../support/job_buffer"
require "active_support/core_ext/integer/inflections"

class AfterDiscardRetryJob < ActiveJob::Base
  class UnhandledError < StandardError; end
  class DefaultsError < StandardError; end
  class CustomCatchError < StandardError; end
  class DiscardableError < StandardError; end
  class CustomDiscardableError < StandardError; end
  class AfterDiscardError < StandardError; end
  class ChildAfterDiscardError < AfterDiscardError; end

  retry_on DefaultsError
  retry_on(CustomCatchError) { |job, error| JobBuffer.add("Dealt with a job that failed to retry in a custom way after #{job.arguments.second} attempts. Message: #{error.message}") }
  retry_on(AfterDiscardError)
  retry_on(ChildAfterDiscardError)

  discard_on DiscardableError
  discard_on(CustomDiscardableError) { |_job, error| JobBuffer.add("Dealt with a job that was discarded in a custom way. Message: #{error.message}") }

  after_discard { |_job, error| JobBuffer.add("Ran after_discard for job. Message: #{error.message}") }

  def perform(raising, attempts)
    if executions < attempts
      JobBuffer.add("Raised #{raising} for the #{executions.ordinalize} time")
      raise raising.constantize
    else
      JobBuffer.add("Successfully completed job")
    end
  end
end
