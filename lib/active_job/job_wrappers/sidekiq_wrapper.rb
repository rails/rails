require 'active_job/parameters'

module ActiveJob
  module JobWrappers
    class SidekiqWrapper
      include Sidekiq::Worker

      def perform(job_name, *args)
        job_name.constantize.perform(*ActiveJob::Parameters.deserialize(args))
      end
    end
  end
end
