require 'resque'
require 'active_job/job_wrappers/resque_wrapper'

module ActiveJob
  module QueueAdapters
    class ResqueAdapter
      class << self
        def queue(job, *args)
          Resque.enqueue *JobWrappers::ResqueWrapper.wrap(job, args)
        end
      end
    end
  end
end