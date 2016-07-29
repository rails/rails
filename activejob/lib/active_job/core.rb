module ActiveJob
  # Provides general behavior that will be included into every Active Job
  # object that inherits from ActiveJob::Base.
  module Core
    extend ActiveSupport::Concern

    included do
      # Job arguments
      attr_accessor :arguments
      attr_writer :serialized_arguments

      # Timestamp when the job should be performed
      attr_accessor :scheduled_at

      # Job Identifier
      attr_accessor :job_id

      # Queue in which the job will reside.
      attr_writer :queue_name

      # Priority that the job will have (lower is more priority).
      attr_writer :priority

      # ID optionally provided by adapter
      attr_accessor :provider_job_id

      # Number of times this job has been executed (which increments on every retry, like after an exception).
      attr_accessor :executions

      # I18n.locale to be used during the job.
      attr_accessor :locale
    end

    # These methods will be included into any Active Job object, adding
    # helpers for de/serialization and creation of job instances.
    module ClassMethods
      # Creates a new job instance from a hash created with +serialize+
      def deserialize(job_data)
        job = job_data['job_class'].constantize.new
        job.deserialize(job_data)
        job
      end

      # Creates a job preconfigured with the given options. You can call
      # perform_later with the job arguments to enqueue the job with the
      # preconfigured options
      #
      # ==== Options
      # * <tt>:wait</tt> - Enqueues the job with the specified delay
      # * <tt>:wait_until</tt> - Enqueues the job at the time specified
      # * <tt>:queue</tt> - Enqueues the job on the specified queue
      # * <tt>:priority</tt> - Enqueues the job with the specified priority
      #
      # ==== Examples
      #
      #    VideoJob.set(queue: :some_queue).perform_later(Video.last)
      #    VideoJob.set(wait: 5.minutes).perform_later(Video.last)
      #    VideoJob.set(wait_until: Time.now.tomorrow).perform_later(Video.last)
      #    VideoJob.set(queue: :some_queue, wait: 5.minutes).perform_later(Video.last)
      #    VideoJob.set(queue: :some_queue, wait_until: Time.now.tomorrow).perform_later(Video.last)
      #    VideoJob.set(queue: :some_queue, wait: 5.minutes, priority: 10).perform_later(Video.last)
      def set(options={})
        ConfiguredJob.new(self, options)
      end
    end

    # Creates a new job instance. Takes the arguments that will be
    # passed to the perform method.
    def initialize(*arguments)
      @arguments  = arguments
      @job_id     = SecureRandom.uuid
      @queue_name = self.class.queue_name
      @priority   = self.class.priority
      @executions = 0
    end

    # Returns a hash with the job data that can safely be passed to the
    # queueing adapter.
    def serialize
      {
        'job_class'  => self.class.name,
        'job_id'     => job_id,
        'queue_name' => queue_name,
        'priority'   => priority,
        'arguments'  => serialize_arguments(arguments),
        'executions' => executions + 1,
        'locale'     => I18n.locale.to_s
      }
    end

    # Attaches the stored job data to the current instance. Receives a hash
    # returned from +serialize+
    #
    # ==== Examples
    #
    #    class DeliverWebhookJob < ActiveJob::Base
    #      def serialize
    #        super.merge('attempt_number' => (@attempt_number || 0) + 1)
    #      end
    #
    #      def deserialize(job_data)
    #        super
    #        @attempt_number = job_data['attempt_number']
    #      end
    #
    #      rescue_from(TimeoutError) do |exception|
    #        raise exception if @attempt_number > 5
    #        retry_job(wait: 10)
    #      end
    #    end
    def deserialize(job_data)
      self.job_id               = job_data['job_id']
      self.provider_job_id      = job_data['provider_job_id']
      self.queue_name           = job_data['queue_name']
      self.priority             = job_data['priority']
      self.serialized_arguments = job_data['arguments']
      self.executions           = job_data['executions']
      self.locale               = job_data['locale'] || I18n.locale.to_s
    end

    private
      def deserialize_arguments_if_needed
        if defined?(@serialized_arguments) && @serialized_arguments.present?
          @arguments = deserialize_arguments(@serialized_arguments)
          @serialized_arguments = nil
        end
      end

      def serialize_arguments(serialized_args)
        Arguments.serialize(serialized_args)
      end

      def deserialize_arguments(serialized_args)
        Arguments.deserialize(serialized_args)
      end
  end
end
