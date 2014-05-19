module ActiveJob
  module JobWrappers
    class SuckerPunchWrapper
      include SuckerPunch::Job

      def perform(job_name, *args)
        job_name.perform(*ActiveJob::Parameters.deserialize(args))
      end
    end
  end
end
