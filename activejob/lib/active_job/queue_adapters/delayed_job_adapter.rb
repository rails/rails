require 'delayed_job'

module ActiveJob
  module QueueAdapters
    class DelayedJobAdapter
      class << self
        def enqueue(job)
          JobWrapper.new.delay(queue: job.queue_name).perform(job.serialize)
        end

        def enqueue_at(job, timestamp)
          JobWrapper.new.delay(queue: job.queue_name, run_at: Time.at(timestamp)).perform(job.serialize)
        end
      end

      class JobWrapper
        def perform(job_data)
          Base.execute(job_data)
        end
      end
    end
  end
end
