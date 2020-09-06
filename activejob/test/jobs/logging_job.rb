# frozen_string_literal: true

class LoggingJob < ActiveJob::Base
  def perform(dummy)
    logger.info "Dummy, here is it: #{dummy}"
  end

  def job_id
    'LOGGING-JOB-ID'
  end
end
