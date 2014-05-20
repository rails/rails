require 'sucker_punch'

module ActiveJob
  module QueueAdapters
    class SuckerPunchAdapter
      class << self
        def queue(job, *args)
          JobWrapper.new.async.perform(job, *args)
        end

        def queue_at(job, timestamp, *args)
          JobWrapper.new.async.later(timestamp, job, *args)
        end
      end

      class JobWrapper
        include SuckerPunch::Job

        def perform(job, *args)
          job.new.perform *Parameters.deserialize(args)
        end

        def later(sec, job_name, *args)
          delay = Time.now.to_f - sec
          after(delay > 0 ? delay : 0) { perform(job_name, *args) }
        end
      end
    end
  end
end
