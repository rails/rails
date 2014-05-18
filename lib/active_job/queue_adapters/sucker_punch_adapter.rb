require 'sucker_punch'
require 'active_job/job_wrappers/sucker_punch_wrapper'

module ActiveJob
  module QueueAdapters
    class SuckerPunchAdapter
      class << self
        def queue(job, *args)
          JobWrappers::SuckerPunchWrapper.new.async.perform(job, *args)
        end
      end
    end
  end
end
