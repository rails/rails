require 'sidekiq'

module ActiveJob
  module QueueAdapters
    # == Sidekiq adapter for Active Job
    #
    # Simple, efficient background processing for Ruby. Sidekiq uses threads to
    # handle many jobs at the same time in the same process. It does not
    # require Rails but will integrate tightly with it to make background
    # processing dead simple.
    #
    # Read more about Sidekiq {here}[http://sidekiq.org].
    #
    # To use Sidekiq set the queue_adapter config to +:sidekiq+.
    #
    #   Rails.application.config.active_job.queue_adapter = :sidekiq
    class SidekiqAdapter
      def enqueue(job) #:nodoc:
        enqueue_at(job)
      end

      def enqueue_at(job, timestamp = nil) #:nodoc:
        options = {}
        options['class'] = JobWrapper
        options['wrapped'] = job.class.to_s
        options['queue'] = job.queue_name
        options['args'] = [ job.serialize]
        options['at'] = timestamp unless timestamp.nil?

        job.provider_job_id = Sidekiq::Client.push options
      end

      class JobWrapper #:nodoc:
        include Sidekiq::Worker

        def perform(job_data)
          Base.execute job_data
        end
      end
    end
  end
end
