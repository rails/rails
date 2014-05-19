require 'delayed_job'

module ActiveJob
  module QueueAdapters
    class DelayedJobAdapter
      class << self
        def queue(job, *args)
          JobWrapper.new.delay(queue: job.queue_name).perform(job, *args)
        end
      end
      
      class JobWrapper
        def perform(job, *args)
          job.perform(*ActiveJob::Parameters.deserialize(args))
        end
      end
    end
  end
end
