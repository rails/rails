require 'sucker_punch'

module ActiveJob
  module QueueAdapters
    class SuckerPunchAdapter
      class << self
        def queue(job, *args)
          JobWrapper.new.async.perform job, *args
        end

        def queue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper
        include SuckerPunch::Job

        def perform(job, *args)
          job.new.perform_with_deserialization *args
        end
      end
    end
  end
end
