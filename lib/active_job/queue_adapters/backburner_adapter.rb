require 'backburner'

module ActiveJob
  module QueueAdapters
    class BackburnerAdapter
      class << self
        def queue(job, *args)
          Backburner::Worker.enqueue JobWrapper, [ job.name, *args ], queue: job.queue_name
        end
      end

      class JobWrapper
        class << self
          def perform(job_name, *args)
            job_name.constantize.new.perform *Parameters.deserialize(args)
          end
        end
      end
    end
  end
end
