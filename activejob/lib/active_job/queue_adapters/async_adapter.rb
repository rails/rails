require 'active_job/async_job'

module ActiveJob
  module QueueAdapters
    # == Active Job Async adapter
    #
    # When enqueuing jobs with the Async adapter the job will be executed
    # asynchronously using {AsyncJob}[http://api.rubyonrails.org/classes/ActiveJob/AsyncJob.html].
    #
    # To use +AsyncJob+ set the queue_adapter config to +:async+.
    #
    #   Rails.application.config.active_job.queue_adapter = :async
    class AsyncAdapter
      def enqueue(job) #:nodoc:
        ActiveJob::AsyncJob.enqueue(job.serialize, queue: job.queue_name)
      end

      def enqueue_at(job, timestamp) #:nodoc:
        ActiveJob::AsyncJob.enqueue_at(job.serialize, timestamp, queue: job.queue_name)
      end
    end
  end
end
