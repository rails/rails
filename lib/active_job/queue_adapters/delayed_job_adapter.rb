require 'delayed_job'

module ActiveJob
  module QueueAdapters
    class DelayedJobAdapter
      class << self
        def queue(job, *args)
          job.delay(queue: job.queue_name).perform(*args)
        end
      end
    end
  end
end
