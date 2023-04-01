# frozen_string_literal: true

require "resque"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/array/access"

begin
  require "resque-scheduler"
rescue LoadError
  begin
    require "resque_scheduler"
  rescue LoadError
    false
  end
end

module ActiveJob
  module QueueAdapters
    # = Resque adapter for Active Job
    #
    # Resque (pronounced like "rescue") is a Redis-backed library for creating
    # background jobs, placing those jobs on multiple queues, and processing
    # them later.
    #
    # Read more about Resque {here}[https://github.com/resque/resque].
    #
    # To use Resque set the queue_adapter config to +:resque+.
    #
    #   Rails.application.config.active_job.queue_adapter = :resque
    class ResqueAdapter
      def enqueue(job) # :nodoc:
        JobWrapper.instance_variable_set(:@queue, job.queue_name)
        Resque.enqueue_to job.queue_name, JobWrapper, job.serialize
      end

      def enqueue_at(job, timestamp) # :nodoc:
        unless Resque.respond_to?(:enqueue_at_with_queue)
          raise NotImplementedError, "To be able to schedule jobs with Resque you need the " \
            "resque-scheduler gem. Please add it to your Gemfile and run bundle install"
        end
        Resque.enqueue_at_with_queue job.queue_name, timestamp, JobWrapper, job.serialize
      end

      class JobWrapper # :nodoc:
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
