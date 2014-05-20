require 'que'

module ActiveJob
  module QueueAdapters
    class QueAdapter
      class << self
        def queue(job, *args)
          JobWrapper.enqueue job, *args, queue: job.queue_name
        end

        def queue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper < Que::Job
        def run(job, *args)
          job.new.perform_with_deserialization *args
        end
      end
    end
  end
end
