class NestedJob < ActiveJob::Base
  def perform
    LoggingJob.enqueue "NestedJob"
  end

  def job_id
    "NESTED-JOB-ID"
  end
end

