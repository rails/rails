# frozen_string_literal: true

require "backburner"

module ActiveJob
  module QueueAdapters
    # = Backburner adapter for Active Job
    #
    # Backburner is a beanstalkd-powered job queue that can handle a very
    # high volume of jobs. You create background jobs and place them on
    # multiple work queues to be processed later. Read more about
    # Backburner {here}[https://github.com/nesquena/backburner].
    #
    # To use Backburner set the queue_adapter config to +:backburner+.
    #
    #   Rails.application.config.active_job.queue_adapter = :backburner
    class BackburnerAdapter < AbstractAdapter
      def check_adapter
        ActiveJob.deprecator.warn <<~MSG.squish
          The built-in `backburner` adapter is deprecated and will be removed in Rails 8.2.
          Please upgrade `backburner` gem to version 1.7 or later to use the `backburner` gem's adapter.
        MSG
      end

      def enqueue(job) # :nodoc:
        response = Backburner::Worker.enqueue(JobWrapper, [job.serialize], queue: job.queue_name, pri: job.priority)
        job.provider_job_id = response[:id] if response.is_a?(Hash)
        response
      end

      def enqueue_at(job, timestamp) # :nodoc:
        delay = timestamp - Time.current.to_f
        response = Backburner::Worker.enqueue(JobWrapper, [job.serialize], queue: job.queue_name, pri: job.priority, delay: delay)
        job.provider_job_id = response[:id] if response.is_a?(Hash)
        response
      end

      class JobWrapper # :nodoc:
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
