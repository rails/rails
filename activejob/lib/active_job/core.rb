# frozen_string_literal: true

module ActiveJob
  # = Active Job \Core
  #
  # Provides general behavior that will be included into every Active Job
  # object that inherits from ActiveJob::Base.
  module Core
    extend ActiveSupport::Concern

    # Job arguments
    attr_accessor :arguments
    attr_writer :serialized_arguments

    # Time when the job should be performed
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

    # Hash that contains the number of times this job handled errors for each specific retry_on declaration.
    # Keys are the string representation of the exceptions listed in the retry_on declaration,
    # while its associated value holds the number of executions where the corresponding retry_on
    # declaration handled one of its listed exceptions.
    attr_accessor :exception_executions

    # I18n.locale to be used during the job.
    attr_accessor :locale

    # Timezone to be used during the job.
    attr_accessor :timezone

    # Track when a job was enqueued
    attr_accessor :enqueued_at

    # Track whether the adapter received the job successfully.
    attr_writer :successfully_enqueued # :nodoc:

    def successfully_enqueued?
      @successfully_enqueued
    end

    # Track any exceptions raised by the backend so callers can inspect the errors.
    attr_accessor :enqueue_error

    # These methods will be included into any Active Job object, adding
    # helpers for de/serialization and creation of job instances.
    module ClassMethods
      # Creates a new job instance from a hash created with +serialize+
      def deserialize(job_data)
        job = job_data["job_class"].constantize.new
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
      def set(options = {})
        ConfiguredJob.new(self, options)
      end
    end

    # Creates a new job instance. Takes the arguments that will be
    # passed to the perform method.
    def initialize(*arguments)
      @arguments  = arguments
      @job_id     = SecureRandom.uuid
      @queue_name = self.class.queue_name
      @scheduled_at = nil
      @priority   = self.class.priority
      @executions = 0
      @exception_executions = {}
      @timezone   = Time.zone&.name
    end
    ruby2_keywords(:initialize)

    # Returns a hash with the job data that can safely be passed to the
    # queuing adapter.
    def serialize
      {
        "job_class"  => self.class.name,
        "job_id"     => job_id,
        "provider_job_id" => provider_job_id,
        "queue_name" => queue_name,
        "priority"   => priority,
        "arguments"  => serialize_arguments_if_needed(arguments),
        "executions" => executions,
        "exception_executions" => exception_executions,
        "locale"     => I18n.locale.to_s,
        "timezone"   => timezone,
        "enqueued_at" => Time.now.utc.iso8601(9),
        "scheduled_at" => scheduled_at ? scheduled_at.utc.iso8601(9) : nil,
      }
    end

    # Attaches the stored job data to the current instance. Receives a hash
    # returned from +serialize+
    #
    # ==== Examples
    #
    #    class DeliverWebhookJob < ActiveJob::Base
    #      attr_writer :attempt_number
    #
    #      def attempt_number
    #        @attempt_number ||= 0
    #      end
    #
    #      def serialize
    #        super.merge('attempt_number' => attempt_number + 1)
    #      end
    #
    #      def deserialize(job_data)
    #        super
    #        self.attempt_number = job_data['attempt_number']
    #      end
    #
    #      rescue_from(Timeout::Error) do |exception|
    #        raise exception if attempt_number > 5
    #        retry_job(wait: 10)
    #      end
    #    end
    def deserialize(job_data)
      self.job_id               = job_data["job_id"]
      self.provider_job_id      = job_data["provider_job_id"]
      self.queue_name           = job_data["queue_name"]
      self.priority             = job_data["priority"]
      self.serialized_arguments = job_data["arguments"]
      self.executions           = job_data["executions"]
      self.exception_executions = job_data["exception_executions"]
      self.locale               = job_data["locale"] || I18n.locale.to_s
      self.timezone             = job_data["timezone"] || Time.zone&.name
      self.enqueued_at          = Time.iso8601(job_data["enqueued_at"]) if job_data["enqueued_at"]
      self.scheduled_at         = Time.iso8601(job_data["scheduled_at"]) if job_data["scheduled_at"]
    end

    # Configures the job with the given options.
    def set(options = {}) # :nodoc:
      self.scheduled_at = options[:wait].seconds.from_now if options[:wait]
      self.scheduled_at = options[:wait_until] if options[:wait_until]
      self.queue_name   = self.class.queue_name_from_part(options[:queue]) if options[:queue]
      self.priority     = options[:priority].to_i if options[:priority]

      self
    end

    private
      def serialize_arguments_if_needed(arguments)
        if arguments_serialized?
          @serialized_arguments
        else
          serialize_arguments(arguments)
        end
      end

      def deserialize_arguments_if_needed
        if arguments_serialized?
          @arguments = deserialize_arguments(@serialized_arguments)
          @serialized_arguments = nil
        end
      end

      def serialize_arguments(arguments)
        Arguments.serialize(arguments)
      end

      def deserialize_arguments(serialized_args)
        Arguments.deserialize(serialized_args)
      end

      def arguments_serialized?
        @serialized_arguments
      end
  end
end
