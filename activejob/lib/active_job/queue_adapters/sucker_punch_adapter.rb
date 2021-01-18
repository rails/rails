# frozen_string_literal: true

require "sucker_punch"

module ActiveJob
  module QueueAdapters
    # == Sucker Punch adapter for Active Job
    #
    # Sucker Punch is a single-process Ruby asynchronous processing library.
    # This reduces the cost of hosting on a service like Heroku along
    # with the memory footprint of having to maintain additional jobs if
    # hosting on a dedicated server. All queues can run within a
    # single application (e.g. Rails, Sinatra, etc.) process.
    #
    # Read more about Sucker Punch {here}[https://github.com/brandonhilkert/sucker_punch].
    #
    # To use Sucker Punch set the queue_adapter config to +:sucker_punch+.
    #
    #   Rails.application.config.active_job.queue_adapter = :sucker_punch
    class SuckerPunchAdapter
      def enqueue(job) #:nodoc:
        if JobWrapper.respond_to?(:perform_async)
          # sucker_punch 2.0 API
          JobWrapper.perform_async job.serialize
        else
          # sucker_punch 1.0 API
          JobWrapper.new.async.perform job.serialize
        end
      end

      def enqueue_at(job, timestamp) #:nodoc:
        if JobWrapper.respond_to?(:perform_in)
          delay = timestamp - Time.current.to_f
          JobWrapper.perform_in delay, job.serialize
        else
          raise NotImplementedError, "sucker_punch 1.0 does not support `enqueued_at`. Please upgrade to version ~> 2.0.0 to enable this behavior."
        end
      end

      def concurrency_reached?(strategy, job)
        false
      end

      def clear_concurrency(strategy, job)
      end

      class JobWrapper #:nodoc:
        include SuckerPunch::Job

        def perform(job_data)
          Base.execute job_data
        end
      end
    end
  end
end
