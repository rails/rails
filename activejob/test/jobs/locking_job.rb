# frozen_string_literal: true

require_relative "../support/job_buffer"

class LockingJob < ActiveJob::Base
  self.lock_timeout = 1.hour
  self.lock_key = Proc.new { |job| job.queue_name }

  after_enqueue do |job|
    JobBuffer.add("Job enqueued")
  end

  def perform
    # Nothing
  end
end
