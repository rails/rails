module ActiveJob
  module QueueAdapters
    # == Test adapter for Active Job
    #
    # The test adapter should be used only in testing. Along with
    # <tt>ActiveJob::TestCase</tt> and <tt>ActiveJob::TestHelper</tt>
    # it makes a great tool to test your Rails application.
    #
    # To use the test adapter set queue_adapter config to +:test+.
    #
    #   Rails.application.config.active_job.queue_adapter = :test
    class TestAdapter
      delegate :name, to: :class
      attr_accessor(:perform_enqueued_jobs, :perform_enqueued_at_jobs)
      attr_writer(:enqueued_jobs, :performed_jobs)

      def initialize
        self.perform_enqueued_jobs = false
        self.perform_enqueued_at_jobs = false
      end

      # Provides a store of all the enqueued jobs with the TestAdapter so you can check them.
      def enqueued_jobs
        @enqueued_jobs ||= []
      end

      # Provides a store of all the performed jobs with the TestAdapter so you can check them.
      def performed_jobs
        @performed_jobs ||= []
      end

      def enqueue(job) #:nodoc:
        if perform_enqueued_jobs
          performed_jobs << {job: job.class, args: job.serialize['arguments'], queue: job.queue_name}
          Base.execute job.serialize
        else
          enqueued_jobs << {job: job.class, args: job.serialize['arguments'], queue: job.queue_name}
        end
      end

      def enqueue_at(job, timestamp) #:nodoc:
        if perform_enqueued_at_jobs
          performed_jobs << {job: job.class, args: job.serialize['arguments'], queue: job.queue_name, at: timestamp}
          Base.execute job.serialize
        else
          enqueued_jobs << {job: job.class, args: job.serialize['arguments'], queue: job.queue_name, at: timestamp}
        end
      end
    end
  end
end
