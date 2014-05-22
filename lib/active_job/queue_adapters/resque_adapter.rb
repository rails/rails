require 'resque'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/array/access'
require 'resque_scheduler'

module ActiveJob
  module QueueAdapters
    class ResqueAdapter
      class << self
        def enqueue(job, *args)
          Resque.enqueue JobWrapper.new(job), job, *args
        end

        def enqueue_at(job, timestamp, *args)
          Resque.enqueue_at timestamp, JobWrapper.new(job), job, *args
        end
      end

      class JobWrapper
        class << self
          def perform(job_name, *args)
            job_name.constantize.new.perform_with_hooks *args
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
