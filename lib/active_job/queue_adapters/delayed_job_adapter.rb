require 'delayed_job'
require 'active_job/job_wrappers/delayed_job_wrapper'

module ActiveJob
  module QueueAdapters
    class DelayedJobAdapter
      class << self
        def queue(job, *args)
          JobWrappers::DelayedJobWrapper.new.delay(queue: job.queue_name).perform(job, *args)
        end
      end
    end
  end
end
