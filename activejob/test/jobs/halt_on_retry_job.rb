# frozen_string_literal: true

require_relative "../support/job_buffer"

class HaltOnRetryJob < ActiveJob::Base
  abort_perform_on_retry true

  def perform
    JobBuffer.add("Executing before retry_job was called")
    if executions < 2
      retry_job
      JobBuffer.add("Executing after retry_job was called")
    end
    JobBuffer.add("Job complete")
  end
end
