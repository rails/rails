require 'sucker_punch'

module ActiveJob
  module QueueAdapters
    class SuckerPunchAdapter
      class << self
        def queue(job, *args)
          JobWrapper.new.async.perform(job, *args)
        end
      end

      class JobWrapper
        include SuckerPunch::Job

        def perform(job_name, *args)
          job_name.new.perform *Parameters.deserialize(args)
        end
      end
    end
  end
end
