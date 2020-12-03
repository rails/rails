# frozen_string_literal: true

require_relative "../support/job_buffer"

class ConcurrencyJobRetryError < StandardError; end

class ConcurrencyJob < ActiveJob::Base
  exclusively_with(keys: ["raising"])

  retry_on ConcurrencyJobRetryError do |job, error|
    puts job.inspect
  end

  after_enqueue do |job|
    JobBuffer.add("Job enqueued with key: #{concurrency_key}")
  end

  def perform(args)
    if args["raising"]
      raise ConcurrencyJobRetryError
    end
  end
end
