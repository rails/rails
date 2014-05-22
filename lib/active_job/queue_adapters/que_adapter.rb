require 'que'

module ActiveJob
  module QueueAdapters
    class QueAdapter
      class << self
        def enqueue(job, *args)
          JobWrapper.enqueue job, *args, queue: job.queue_name
        end

        def enqueue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper < Que::Job
        def run(job, *args)
          job.new.perform_with_hooks *args
        end
      end
    end
  end
end
