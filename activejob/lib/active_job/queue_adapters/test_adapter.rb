module ActiveJob
  module QueueAdapters
    class TestAdapter
      attr_accessor(:perform_enqueued_jobs) { false }
      attr_accessor(:perform_enqueued_at_jobs) { false }
      delegate :name, to: :class

      # Provides a store of all the enqueued jobs with the TestAdapter so you can check them.
      def enqueued_jobs
        @enqueued_jobs ||= []
      end

      # Allows you to overwrite the default enqueued jobs store from an array to some
      # other object.  If you just want to clear the store,
      # call ActiveJob::QueueAdapters::TestAdapter.enqueued_jobs.clear.
      #
      # If you place another object here, please make sure it responds to:
      #
      # * << (message)
      # * clear
      # * length
      # * size
      # * and other common Array methods
      def enqueued_jobs=(val)
        @enqueued_jobs = val
      end

      # Provides a store of all the performed jobs with the TestAdapter so you can check them.
      def performed_jobs
        @performed_jobs ||= []
      end

      # Allows you to overwrite the default performed jobs store from an array to some
      # other object.  If you just want to clear the store,
      # call ActiveJob::QueueAdapters::TestAdapter.performed_jobs.clear.
      #
      # If you place another object here, please make sure it responds to:
      #
      # * << (message)
      # * clear
      # * length
      # * size
      # * and other common Array methods
      def performed_jobs=(val)
        @performed_jobs = val
      end

      def enqueue(job, *args)
        if perform_enqueued_jobs?
          performed_jobs << {job: job, args: args, queue: job.queue_name}
          job.new.execute(*args)
        else
          enqueued_jobs << {job: job, args: args, queue: job.queue_name}
        end
      end

      def enqueue_at(job, timestamp, *args)
        if perform_enqueued_at_jobs?
          performed_jobs << {job: job, args: args, queue: job.queue_name, run_at: timestamp}
          job.new.execute(*args)
        else
          enqueued_jobs << {job: job, args: args, queue: job.queue_name, run_at: timestamp}
        end
      end

      private
        def perform_enqueued_jobs?
          perform_enqueued_jobs
        end

        def perform_enqueued_at_jobs?
          perform_enqueued_at_jobs
        end
    end
  end
end
