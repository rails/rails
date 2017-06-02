class CustomTagsLoggingJob < ActiveJob::Base
  def perform(dummy, log_tags = nil)
    logger.info "Dummy, here is it: #{dummy}"
  end

  def job_id
    "LOGGING-JOB-ID"
  end
end
