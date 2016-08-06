require "active_job/arguments"

module ActiveJob
  # Provides behavior for enqueuing jobs.
  module Enqueuing
    extend ActiveSupport::Concern

    # Includes the +perform_later+ method for job initialization.
    module ClassMethods
      # Push a job onto the queue. The arguments must be legal JSON types
      # (string, int, float, nil, true, false, hash or array) or
      # GlobalID::Identification instances. Arbitrary Ruby objects
      # are not supported.
      #
      # Returns an instance of the job class queued with arguments available in
      # Job#arguments.
      def perform_later(*args)
        job_or_instantiate(*args).enqueue
      end

      protected
        def job_or_instantiate(*args)
          args.first.is_a?(self) ? args.first : new(*args)
        end
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
    def enqueue(options={})
      self.scheduled_at = options[:wait].seconds.from_now.to_f if options[:wait]
      self.scheduled_at = options[:wait_until].to_f if options[:wait_until]
      self.queue_name   = self.class.queue_name_from_part(options[:queue]) if options[:queue]
      self.priority     = options[:priority].to_i if options[:priority]
      run_callbacks :enqueue do
        if self.scheduled_at
          self.class.queue_adapter.enqueue_at self, self.scheduled_at
        else
          self.class.queue_adapter.enqueue self
        end
      end
      self
    end
  end
end
