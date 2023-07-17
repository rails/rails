# frozen_string_literal: true

class LoggingJob < ActiveJob::Base
  def perform(*dummy)
    logger.info "Dummy, here is it: #{dummy.join(" ")}"
  end

  def job_id
    "LOGGING-JOB-ID"
  end
end
