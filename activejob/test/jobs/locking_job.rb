# frozen_string_literal: true

require_relative "../support/job_buffer"

class LockingJobRetryError < StandardError; end

class LockingJob < ActiveJob::Base
  locked_by timeout: 1.hour, key: -> job {
    if job.arguments.blank?
      "raising_false"
    else
      "raising_#{job.arguments[0][:raising]}"
    end
  }

  retry_on LockingJobRetryError do |job, error|
    # Nothing
  end

  after_enqueue do |job|
    JobBuffer.add("Job enqueued with key: #{lock_key}")
  end

  def perform(raising: false)
    if raising
      raise LockingJobRetryError
    end
  end
end
