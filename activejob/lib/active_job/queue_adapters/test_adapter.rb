module ActiveJob
  module QueueAdapters
    class TestAdapter
      delegate :name, to: :class
      attr_accessor(:perform_enqueued_jobs, :perform_enqueued_at_jobs)
      attr_writer(:enqueued_jobs, :performed_jobs)

      # Provides a store of all the enqueued jobs with the TestAdapter so you can check them.
      def enqueued_jobs
        @enqueued_jobs ||= []
      end

      # Provides a store of all the performed jobs with the TestAdapter so you can check them.
      def performed_jobs
        @performed_jobs ||= []
      end

      def enqueue(job)
        if perform_enqueued_jobs
          performed_jobs << {job: job.class, args: job.arguments, queue: job.queue_name}
          job.perform_now
        else
          enqueued_jobs << {job: job.class, args: job.arguments, queue: job.queue_name}
        end
      end

      def enqueue_at(job, timestamp)
        if perform_enqueued_at_jobs
          performed_jobs << {job: job.class, args: job.arguments, queue: job.queue_name, at: timestamp}
          job.perform_now
        else
          enqueued_jobs << {job: job.class, args: job.arguments, queue: job.queue_name, at: timestamp}
        end
      end
    end
  end
end
