require 'queue_classic'

module ActiveJob
  module QueueAdapters
    class QueueClassicAdapter
      class << self
        def queue(job, *args)
          QC::Queue.new(job.queue_name).enqueue("#{JobWrapper.name}.perform", job, *args)
        end

        def queue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper
        def self.perform(job, *args)
          job.new.perform_with_deserialization *args
        end
      end
    end
  end
end
