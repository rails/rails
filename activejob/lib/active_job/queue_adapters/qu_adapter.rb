require "qu"

module ActiveJob
  module QueueAdapters
    # == Qu adapter for Active Job
    #
    # Qu is a Ruby library for queuing and processing background jobs. It is
    # heavily inspired by delayed_job and Resque. Qu was created to overcome
    # some shortcomings in the existing queuing libraries.
    # The advantages of Qu are: Multiple backends (redis, mongo), jobs are
    # requeued when worker is killed, resque-like API.
    #
    # Read more about Qu {here}[https://github.com/bkeepers/qu].
    #
    # To use Qu set the queue_adapter config to +:qu+.
    #
    #   Rails.application.config.active_job.queue_adapter = :qu
    class QuAdapter
      def enqueue(job, *args) #:nodoc:
        qu_job = Qu::Payload.new(klass: JobWrapper, args: [job.serialize]).tap do |payload|
          payload.instance_variable_set(:@queue, job.queue_name)
        end.push

        # qu_job can be nil depending on the configured backend
        job.provider_job_id = qu_job.id unless qu_job.nil?
        qu_job
      end

      def enqueue_at(job, timestamp, *args) #:nodoc:
        raise NotImplementedError, "This queueing backend does not support scheduling jobs. To see what features are supported go to http://api.rubyonrails.org/classes/ActiveJob/QueueAdapters.html"
      end

      class JobWrapper < Qu::Job #:nodoc:
        def initialize(job_data)
          @job_data  = job_data
        end

        def perform
          Base.execute @job_data
        end
      end
    end
  end
end
