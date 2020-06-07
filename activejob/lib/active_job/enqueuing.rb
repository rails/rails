# frozen_string_literal: true

require "active_job/arguments"

module ActiveJob
  # Provides behavior for enqueuing jobs.
  module Enqueuing
    extend ActiveSupport::Concern

    # Includes the +perform_later+ method for job initialization.
    module ClassMethods
      # Push a job onto the queue. By default the arguments must be either String,
      # Integer, Float, NilClass, TrueClass, FalseClass, BigDecimal, Symbol, Date,
      # Time, DateTime, ActiveSupport::TimeWithZone, ActiveSupport::Duration,
      # Hash, ActiveSupport::HashWithIndifferentAccess, Array or
      # GlobalID::Identification instances, although this can be extended by adding
      # custom serializers.
      #
      # Returns an instance of the job class queued with arguments available in
      # Job#arguments.
      def perform_later(*args)
        job_or_instantiate(*args).enqueue
      end
      ruby2_keywords(:perform_later) if respond_to?(:ruby2_keywords, true)

      private
        def job_or_instantiate(*args) # :doc:
          args.first.is_a?(self) ? args.first : new(*args)
        end
        ruby2_keywords(:job_or_instantiate) if respond_to?(:ruby2_keywords, true)
    end

    # Enqueues the job to be performed by the queue adapter.
    #
    # ==== Options
    # * <tt>:wait</tt> - Enqueues the job with the specified delay
    # * <tt>:wait_until</tt> - Enqueues the job at the time specified
    # * <tt>:queue</tt> - Enqueues the job on the specified queue
    # * <tt>:priority</tt> - Enqueues the job with the specified priority
    #
    # ==== Examples
    #
    #    my_job_instance.enqueue
    #    my_job_instance.enqueue wait: 5.minutes
    #    my_job_instance.enqueue queue: :important
    #    my_job_instance.enqueue wait_until: Date.tomorrow.midnight
    #    my_job_instance.enqueue priority: 10
    def enqueue(options = {})
      self.scheduled_at = options[:wait].seconds.from_now.to_f if options[:wait]
      self.scheduled_at = options[:wait_until].to_f if options[:wait_until]
      self.queue_name   = self.class.queue_name_from_part(options[:queue]) if options[:queue]
      self.priority     = options[:priority].to_i if options[:priority]
      successfully_enqueued = false

      run_callbacks :enqueue do
        if scheduled_at
          queue_adapter.enqueue_at self, scheduled_at
        else
          queue_adapter.enqueue self
        end

        successfully_enqueued = true
      end

      if successfully_enqueued
        self
      else
        if self.class.return_false_on_aborted_enqueue
          false
        else
          ActiveSupport::Deprecation.warn(
            "Rails 6.1 will return false when the enqueuing is aborted. Make sure your code doesn't depend on it" \
            " returning the instance of the job and set `config.active_job.return_false_on_aborted_enqueue = true`" \
            " to remove the deprecations."
          )

          self
        end
      end
    end
  end
end
