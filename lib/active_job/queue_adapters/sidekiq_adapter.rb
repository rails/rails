require 'sidekiq'
require 'active_job/job_wrappers/sidekiq_wrapper'

module ActiveJob
  module QueueAdapters
    class SidekiqAdapter
      class << self
        def queue(job, *args)
          JobWrappers::SidekiqWrapper.perform_async(job, *args)
        end
      end
    end
  end
end
