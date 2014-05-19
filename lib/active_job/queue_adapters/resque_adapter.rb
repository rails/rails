require 'resque'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/array/access'

module ActiveJob
  module QueueAdapters
    class ResqueAdapter
      class << self
        def queue(job, *args)
          Resque.enqueue JobWrapper.new(job), job, *args
        end
      end

      class JobWrapper
        class << self
          def perform(job_name, *args)
            job_name.constantize.new.perform *Parameters.deserialize(args)
          end
        end

        def initialize(job)
          @queue = job.queue_name
        end

        def to_s
          self.class.name
        end
      end
    end
  end
end
