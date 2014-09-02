require 'qu'

module ActiveJob
  module QueueAdapters
    class QuAdapter
      class << self
        def enqueue(job, *args)
          Qu::Payload.new(klass: JobWrapper, args: [job.name, *args]).tap do |payload|
            payload.instance_variable_set(:@queue, job.queue_name)
          end.push
        end

        def enqueue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper < Qu::Job
        def initialize(job_name, *args)
          @job  = job_name.constantize
          @args = args
        end

        def perform
          @job.new.execute(*@args)
        end
      end
    end
  end
end
