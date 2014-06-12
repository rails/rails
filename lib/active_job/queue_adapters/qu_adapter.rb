require 'qu'

module ActiveJob
  module QueueAdapters
    class QuAdapter
      class << self
        def enqueue(job, *args)
          Qu::Payload.new(klass: JobWrapper, args: [job, *args], queue: job.queue_name).push
        end

        def enqueue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper < Qu::Job
        def initialize(job, *args)
          @job  = job
          @args = args
        end

        def perform
          @job.new.execute *@args
        end
      end
    end
  end
end
