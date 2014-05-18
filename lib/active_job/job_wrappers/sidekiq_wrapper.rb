module ActiveJob
  module JobWrappers
    class SidekiqWrapper
      include Sidekiq::Worker

      def perform(job_name, *args)
        job_name.constantize.perform(*args)
      end
    end
  end
end
