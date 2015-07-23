require 'backburner'

module ActiveJob
  module QueueAdapters
    # == Backburner adapter for Active Job
    #
    # Backburner is a beanstalkd-powered job queue that can handle a very
    # high volume of jobs. You create background jobs and place them on
    # multiple work queues to be processed later. Read more about
    # Backburner {here}[https://github.com/nesquena/backburner].
    #
    # To use Backburner set the queue_adapter config to +:backburner+.
    #
    #   Rails.application.config.active_job.queue_adapter = :backburner
    class BackburnerAdapter
      def enqueue(job) #:nodoc:
        enqueue_at(job)
      end

      def enqueue_at(job, timestamp = nil) #:nodoc:
        options = {}
        options[:queue] = job.queue_name
        options[:delay] = timestamp = Time.current.to_f unless timestamp.nil?

        Backburner::Worker.enqueue JobWrapper, [ job.serialize ], options
      end

      class JobWrapper #:nodoc:
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
