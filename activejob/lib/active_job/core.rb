module ActiveJob
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
    end

    # These methods will be included into any Active Job object, adding
    # helpers for de/serialization and creation of job instances.
    module ClassMethods
      # Creates a new job instance from a hash created with +serialize+
      def deserialize(job_data)
        job                      = job_data['job_class'].constantize.new
        job.job_id               = job_data['job_id']
        job.queue_name           = job_data['queue_name']
        job.serialized_arguments = job_data['arguments']
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
      #
      # ==== Examples
      #
      #    VideoJob.set(queue: :some_queue).perform_later(Video.last)
      #    VideoJob.set(wait: 5.minutes).perform_later(Video.last)
      #    VideoJob.set(wait_until: Time.now.tomorrow).perform_later(Video.last)
      #    VideoJob.set(queue: :some_queue, wait: 5.minutes).perform_later(Video.last)
      #    VideoJob.set(queue: :some_queue, wait_until: Time.now.tomorrow).perform_later(Video.last)
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
    end

    # Returns a hash with the job data that can safely be passed to the
    # queueing adapter.
    def serialize
      {
        'job_class'  => self.class.name,
        'job_id'     => job_id,
        'queue_name' => queue_name,
        'arguments'  => serialize_arguments(arguments)
      }
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
