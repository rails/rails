module ActiveJob
  module JobWrappers
    class DelayedJobWrapper
      def perform(job, *args)
        job.perform(*ActiveJob::Parameters.deserialize(args))
      end
    end
  end
end
