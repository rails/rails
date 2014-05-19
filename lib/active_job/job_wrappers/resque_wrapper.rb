require 'resque'

require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/array/access'

module ActiveJob
  module JobWrappers
    class ResqueWrapper
      class << self
        def wrap(job, args)
          [ new(job), *args.prepend(job) ]
        end

        def perform(job_name, *args)
          job_name.constantize.perform(*ActiveJob::Parameters.deserialize(args))
        end
      end


      def initialize(job)
        @queue = job.queue_name
      end
      
      def to_s
        self.class.to_s
      end
    end
  end
end
