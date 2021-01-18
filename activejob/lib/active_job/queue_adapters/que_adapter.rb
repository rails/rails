# frozen_string_literal: true

require "que"

module ActiveJob
  module QueueAdapters
    # == Que adapter for Active Job
    #
    # Que is a high-performance alternative to DelayedJob or QueueClassic that
    # improves the reliability of your application by protecting your jobs with
    # the same ACID guarantees as the rest of your data. Que is a queue for
    # Ruby and PostgreSQL that manages jobs using advisory locks.
    #
    # Read more about Que {here}[https://github.com/chanks/que].
    #
    # To use Que set the queue_adapter config to +:que+.
    #
    #   Rails.application.config.active_job.queue_adapter = :que
    class QueAdapter
      def enqueue(job) #:nodoc:
        que_job = JobWrapper.enqueue job.serialize, priority: job.priority, queue: job.queue_name
        job.provider_job_id = que_job.attrs["job_id"]
        que_job
      end

      def enqueue_at(job, timestamp) #:nodoc:
        que_job = JobWrapper.enqueue job.serialize, priority: job.priority, queue: job.queue_name, run_at: Time.at(timestamp)
        job.provider_job_id = que_job.attrs["job_id"]
        que_job
      end

      def concurrency_reached?(strategy, job)
        false
      end

      def clear_concurrency(strategy, job)
      end

      class JobWrapper < Que::Job #:nodoc:
        def run(job_data)
          Base.execute job_data
        end
      end
    end
  end
end
