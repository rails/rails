require 'queue_classic'

module ActiveJob
  module QueueAdapters
    class QueueClassicAdapter
      class << self
        def queue(job, *args)
          QC::Queue.new(job.queue_name).enqueue("#{JobWrapper.name}.perform", job, *args)
        end
      end

      class JobWrapper
        def self.perform(job, *args)
          job.new.perform *Parameters.deserialize(args)
        end
      end
    end
  end
end
