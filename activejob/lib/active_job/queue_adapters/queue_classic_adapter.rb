require 'queue_classic'

module ActiveJob
  module QueueAdapters
    class QueueClassicAdapter
      class << self
        def enqueue(job, *args)
          QC::Queue.new(job.queue_name).enqueue("#{JobWrapper.name}.perform", job.name, *args)
        end

        def enqueue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper
        class << self
          def perform(job_name, *args)
            job_name.constantize.new.execute(*args)
          end
        end
      end
    end
  end
end
