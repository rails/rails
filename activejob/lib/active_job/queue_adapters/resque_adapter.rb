require 'resque'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/array/access'

begin
  require 'resque-scheduler'
rescue LoadError
  begin
    require 'resque_scheduler'
  rescue LoadError
    false
  end
end

module ActiveJob
  module QueueAdapters
    class ResqueAdapter
      class << self
        def enqueue(job)
          Resque.enqueue_to job.queue_name, JobWrapper, job.serialize
        end

        def enqueue_at(job, timestamp)
          unless Resque.respond_to?(:enqueue_at_with_queue)
            raise NotImplementedError, "To be able to schedule jobs with Resque you need the " \
              "resque-scheduler gem. Please add it to your Gemfile and run bundle install"
          end
          Resque.enqueue_at_with_queue job.queue_name, timestamp, JobWrapper, job.serialize
        end
      end

      class JobWrapper
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
