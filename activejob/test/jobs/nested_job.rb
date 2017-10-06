# frozen_string_literal: true

class NestedJob < ActiveJob::Base
  def perform
    LoggingJob.perform_later "NestedJob"
  end

  def job_id
    "NESTED-JOB-ID"
  end
end
