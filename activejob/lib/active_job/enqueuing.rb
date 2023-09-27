# frozen_string_literal: true

require "active_job/arguments"

module ActiveJob
  # Provides behavior for enqueuing jobs.

  # Can be raised by adapters if they wish to communicate to the caller a reason
  # why the adapter was unexpectedly unable to enqueue a job.
  class EnqueueError < StandardError; end

  class << self
    # Push many jobs onto the queue at once without running enqueue callbacks.
    # Queue adapters may communicate the enqueue status of each job by setting
    # successfully_enqueued and/or enqueue_error on the passed-in job instances.
    def perform_all_later(*jobs)
      jobs.flatten!
      jobs.group_by(&:queue_adapter).each do |queue_adapter, adapter_jobs|
        instrument_enqueue_all(queue_adapter, adapter_jobs) do
          if queue_adapter.respond_to?(:enqueue_all)
            queue_adapter.enqueue_all(adapter_jobs)
          else
            adapter_jobs.each do |job|
              job.successfully_enqueued = false
              if job.scheduled_at
                queue_adapter.enqueue_at(job, job._scheduled_at_time.to_f)
              else
                queue_adapter.enqueue(job)
              end
              job.successfully_enqueued = true
            rescue EnqueueError => e
              job.enqueue_error = e
            end
            adapter_jobs.count(&:successfully_enqueued?)
          end
        end
      end
      nil
    end
  end

  module Enqueuing
    extend ActiveSupport::Concern

    # Includes the +perform_later+ method for job initialization.
    module ClassMethods
      # Push a job onto the queue. By default the arguments must be either String,
      # Integer, Float, NilClass, TrueClass, FalseClass, BigDecimal, Symbol, Date,
      # Time, DateTime, ActiveSupport::TimeWithZone, ActiveSupport::Duration,
      # Hash, ActiveSupport::HashWithIndifferentAccess, Array, Range, or
      # GlobalID::Identification instances, although this can be extended by adding
      # custom serializers.
      #
      # Returns an instance of the job class queued with arguments available in
      # Job#arguments or false if the enqueue did not succeed.
      #
      # After the attempted enqueue, the job will be yielded to an optional block.
      def perform_later(...)
        job = job_or_instantiate(...)
        enqueue_result = job.enqueue

        yield job if block_given?

        enqueue_result
      end

      private
        def job_or_instantiate(*args) # :doc:
          args.first.is_a?(self) ? args.first : new(*args)
        end
        ruby2_keywords(:job_or_instantiate)
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
      set(options)
      self.successfully_enqueued = false

      run_callbacks :enqueue do
        if scheduled_at
          queue_adapter.enqueue_at self, _scheduled_at_time.to_f
        else
          queue_adapter.enqueue self
        end

        self.successfully_enqueued = true
      rescue EnqueueError => e
        self.enqueue_error = e
      end

      if successfully_enqueued?
        self
      else
        false
      end
    end
  end
end
