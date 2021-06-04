# frozen_string_literal: true

class DisableLogJob < ActiveJob::Base
  self.log_arguments = false

  def perform(dummy)
    logger.info "Dummy, here is it: #{dummy}"
  end

  def job_id
    "LOGGING-JOB-ID"
  end
end
