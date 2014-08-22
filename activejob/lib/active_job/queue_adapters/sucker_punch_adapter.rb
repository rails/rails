require 'sucker_punch'

module ActiveJob
  module QueueAdapters
    class SuckerPunchAdapter
      class << self
        def enqueue(job, *args)
          JobWrapper.new.async.perform job, *args
        end

        def enqueue_at(job, timestamp, *args)
          JobWrapper.new.async.later((timestamp - Time.now.to_i).round, job, *args)
        end
      end

      class JobWrapper
        include SuckerPunch::Job

        def perform(job, *args)
          job.new.execute(*args)
        end

        def later(sec, job, *args)
          after(sec) { perform(job, *args) }
        end
      end
    end
  end
end
