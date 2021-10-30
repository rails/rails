# frozen_string_literal: true

class LoggingJob < ActiveJob::Base
  def perform(*args)
    logger.info "Dummy, here is it: #{args.join(', ')}"
  end

  def job_id
    "LOGGING-JOB-ID"
  end
end
