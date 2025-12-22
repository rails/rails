# frozen_string_literal: true

module ActiveJob
  module QueueAdapters
    # = Test adapter for Active Job
    #
    # The test adapter should be used only in testing. Along with
    # ActiveJob::TestCase and ActiveJob::TestHelper
    # it makes a great tool to test your \Rails application.
    #
    # To use the test adapter set +queue_adapter+ config to +:test+.
    #
    #   Rails.application.config.active_job.queue_adapter = :test
    class TestAdapter < AbstractAdapter
      class MaximumSideEffectsReached < StandardError; end

      class_attribute :maximum_side_effects, default: nil
      attr_accessor(:perform_enqueued_jobs, :perform_enqueued_at_jobs, :filter, :reject, :queue, :at, :stopping, :maximum_side_effects_override)
      attr_writer(:enqueued_jobs, :performed_jobs)

      # Provides a store of all the enqueued jobs with the TestAdapter so you can check them.
      def enqueued_jobs
        @enqueued_jobs ||= []
      end

      # Provides a store of all the performed jobs with the TestAdapter so you can check them.
      def performed_jobs
        @performed_jobs ||= []
      end

      # Provides a count of all the performed jobs to check if the maximum side effects threshold has been reached.
      def performed_jobs_count
        @performed_jobs_count ||= 0
      end

      # Tracks the execution of a job and raises an error if the maximum side effects threshold has been reached.
      def track_job_execution!
        check_side_effects_threshold!
        increment_performed_jobs_count!
      end

      def increment_performed_jobs_count!
        @performed_jobs_count = performed_jobs_count + 1
      end

      def reset_performed_jobs_count!
        @performed_jobs_count = 0
      end

      def enqueue(job) # :nodoc:
        job_data = job_to_hash(job)
        perform_or_enqueue(perform_enqueued_jobs && !filtered?(job), job, job_data)
      end

      def enqueue_at(job, timestamp) # :nodoc:
        job_data = job_to_hash(job, at: timestamp)
        perform_or_enqueue(perform_enqueued_at_jobs && !filtered?(job), job, job_data)
      end

      def stopping?
        @stopping.is_a?(Proc) ? @stopping.call : @stopping
      end

      private
        def job_to_hash(job, extras = {})
          job.serialize.tap do |job_data|
            job_data[:job] = job.class
            job_data[:args] = job_data.fetch("arguments")
            job_data[:queue] = job_data.fetch("queue_name")
            job_data[:priority] = job_data.fetch("priority")
          end.merge(extras)
        end

        def perform_or_enqueue(perform, job, job_data)
          if perform
            track_job_execution!
            performed_jobs << job_data
            Base.execute(job.serialize)
          else
            enqueued_jobs << job_data
          end
        end

        def check_side_effects_threshold!
          threshold = maximum_side_effects_override || self.class.maximum_side_effects
          return unless threshold

          if performed_jobs_count >= threshold
            raise MaximumSideEffectsReached,
              "Maximum side effects threshold of #{threshold} reached. " \
              "#{performed_jobs_count} jobs have already been performed. " \
              "Consider using perform_enqueued_jobs with `only:` or `except:` or increase the threshold."
          end
        end

        def filtered?(job)
          filtered_queue?(job) || filtered_job_class?(job) || filtered_time?(job)
        end

        def filtered_time?(job)
          job.scheduled_at > at if at && job.scheduled_at
        end

        def filtered_queue?(job)
          if queue
            job.queue_name != queue.to_s
          end
        end

        def filtered_job_class?(job)
          if filter
            !filter_as_proc(filter).call(job)
          elsif reject
            filter_as_proc(reject).call(job)
          end
        end

        def filter_as_proc(filter)
          return filter if filter.is_a?(Proc)

          ->(job) { Array(filter).include?(job.class) }
        end
    end
  end
end
