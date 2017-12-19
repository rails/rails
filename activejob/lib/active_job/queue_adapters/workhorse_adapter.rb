# frozen_string_literal: true

require "workhorse"

module ActiveJob
  module QueueAdapters
    # == Workhorse adapter for Active Job
    #
    # Workhorse is a multi-threaded job backend with database queuing for ruby.
    # Jobs are persisted in the database using ActiveRecird.
    # Read more about Workhorse {here}[https://github.com/sitrox/activejob].
    #
    # To use Workhorse, set the queue_adapter config to +:workhorse+.
    #
    #   Rails.application.config.active_job.queue_adapter = :workhorse
    class WorkhorseAdapter
      def enqueue(job) #:nodoc:
        Workhorse.enqueue_active_job(job)
      end

      def enqueue_at(job, timestamp) #:nodoc:
        raise NotImplementedError, "This queueing backend does not support scheduling jobs out-of-the-box. Please consult the Workhorse FAQ for more information on how to schedule jobs."
      end
    end
  end
end
