require 'sucker_punch'

module ActiveJob
  module QueueAdapters
    class SuckerPunchAdapter
      class << self
        def queue(job, *args)
          JobWrapper.new.async.perform(job, *args)
        end

        def queue_at(job, timestamp, *args)
          delay = Time.now.to_f - timestamp
          if delay > 0
            JobWrapper.new.async.later(delay, job, *args)
          else
            JobWrapper.new.async.perform(job, *args)
          end
        end
      end

      class JobWrapper
        include SuckerPunch::Job

        def perform(job, *args)
          job.new.perform *Parameters.deserialize(args)
        end

        def later(sec, job_name, *args)
          after(sec) { perform(job_name, *args) }
        end
      end
    end
  end
end
