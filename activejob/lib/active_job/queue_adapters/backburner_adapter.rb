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
      class << self
        def enqueue(job) #:nodoc:
          Backburner::Worker.enqueue JobWrapper, [ job.serialize ], queue: job.queue_name
        end

        def enqueue_at(job, timestamp) #:nodoc:
          delay = timestamp - Time.current.to_f
          Backburner::Worker.enqueue JobWrapper, [ job.serialize ], queue: job.queue_name, delay: delay
        end
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
