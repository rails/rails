require 'delayed_job'

module ActiveJob
  module QueueAdapters
    class DelayedJobAdapter
      class << self
        def enqueue(job, *args)
          JobWrapper.new.delay(queue: job.queue_name).perform(job, *args)
        end

        def enqueue_at(job, timestamp, *args)
          JobWrapper.new.delay(queue: job.queue_name, run_at: Time.at(timestamp)).perform(job, *args)
        end
      end

      class JobWrapper
        def perform(job, *args)
          job.new.execute(*args)
        end
      end
    end
  end
end
