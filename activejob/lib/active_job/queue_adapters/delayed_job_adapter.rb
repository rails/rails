require 'delayed_job'

module ActiveJob
  module QueueAdapters
    # == Delayed Job adapter for Active Job
    #
    # Delayed::Job (or DJ) encapsulates the common pattern of asynchronously
    # executing longer tasks in the background. Although DJ can have many
    # storage backends, one of the most used is based on Active Record.
    # Read more about Delayed Job {here}[https://github.com/collectiveidea/delayed_job].
    #
    # To use Delayed Job, set the queue_adapter config to +:delayed_job+.
    #
    #   Rails.application.config.active_job.queue_adapter = :delayed_job
    class DelayedJobAdapter
      class << self
        def enqueue(job) #:nodoc:
          enqueue_at(job, nil)
        end

        def enqueue_at(job, timestamp) #:nodoc:
          options = {}
          options[:queue]    = job.queue_name
          options[:priority] = job.priority if job.priority
          options[:run_at]   = Time.at(timestamp) if timestamp
          Delayed::Job.enqueue(JobWrapper.new(job.serialize), options)
        end
      end

      class JobWrapper #:nodoc:
        attr_accessor :job_data

        def initialize(job_data)
          @job_data = job_data
        end

        def perform
          Base.execute(job_data)
        end
      end
    end
  end
end
