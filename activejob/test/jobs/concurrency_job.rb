# frozen_string_literal: true

require_relative "../support/job_buffer"

class ConcurrencyJobRetryError < StandardError; end

class ConcurrencyJob < ActiveJob::Base
  exclusively_with(keys: ["raising"])

  retry_on ConcurrencyJobRetryError do |job, error|
    puts job.inspect
  end

  after_enqueue do |job|
    JobBuffer.add("Job enqueued with key: #{concurrency_strategies.first.build_key(job)}")
  end

  def perform(args)
    if args["raising"]
      raise ConcurrencyJobRetryError
    end
  end
end

class MultipleConcurrencyStrategiesJob < ActiveJob::Base
  enqueue_exclusively_with(limit: 2, keys: ["resource_id"])
  perform_exclusively_with(keys: ["resource_id"])

  def perform(args)
    JobBuffer.add("Job enqueued with multiple concurrency strategies")
  end
end

class PrefixConcurrencyJob < ActiveJob::Base
  enqueue_exclusively_with(keys: ["resource_id"], prefix: "my_job")

  def perform(args)
    JobBuffer.add("Job enqueued with custom concurrency prefix")
  end
end
