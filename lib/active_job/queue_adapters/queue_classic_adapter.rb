require 'queue_classic'

module ActiveJob
  module QueueAdapters
    class QueueClassicAdapter
      class << self
        def enqueue(job, *args)
          QC::Queue.new(job.queue_name).enqueue("#{JobWrapper.name}.perform", job, *args)
        end

        def enqueue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper
        def self.perform(job, *args)
          job.new.perform_with_hooks *args
        end
      end
    end
  end
end
