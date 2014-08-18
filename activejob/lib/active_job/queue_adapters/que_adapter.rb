require 'que'

module ActiveJob
  module QueueAdapters
    class QueAdapter
      class << self
        def enqueue(job, *args)
          JobWrapper.enqueue job.name, *args, queue: job.queue_name
        end

        def enqueue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper < Que::Job
        def run(job_name, *args)
          job_name.constantize.new.execute(*args)
        end
      end
    end
  end
end
