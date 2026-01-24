# frozen_string_literal: true

require "delayed_job"
require "active_support/core_ext/string/inflections"

module ActiveJob
  module QueueAdapters
    # = Delayed Job adapter for Active Job
    #
    # Delayed::Job (or DJ) encapsulates the common pattern of asynchronously
    # executing longer tasks in the background. Although DJ can have many
    # storage backends, one of the most used is based on Active Record.
    # Read more about Delayed Job {here}[https://github.com/collectiveidea/delayed_job].
    #
    # To use Delayed Job, set the queue_adapter config to +:delayed_job+.
    #
    #   Rails.application.config.active_job.queue_adapter = :delayed_job
    class DelayedJobAdapter < AbstractAdapter
      def check_adapter
        ActiveJob.deprecator.warn <<~MSG.squish
          The built-in `delayed_job` adapter is deprecated and will be removed in Rails 9.0.
          Please upgrade `delayed_job` gem to version 4.2.0 or later to use the `delayed_job` gem's adapter.
        MSG
      end

      def enqueue(job) # :nodoc:
        delayed_job = Delayed::Job.enqueue(JobWrapper.new(job.serialize), queue: job.queue_name, priority: job.priority)
        job.provider_job_id = delayed_job.id
        delayed_job
      end

      def enqueue_at(job, timestamp) # :nodoc:
        delayed_job = Delayed::Job.enqueue(JobWrapper.new(job.serialize), queue: job.queue_name, priority: job.priority, run_at: Time.at(timestamp))
        job.provider_job_id = delayed_job.id
        delayed_job
      end

      class JobWrapper # :nodoc:
        attr_accessor :job_data

        def initialize(job_data)
          @job_data = job_data
        end

        def display_name
          base_name = "#{job_data["job_class"]} [#{job_data["job_id"]}] from DelayedJob(#{job_data["queue_name"]})"

          return base_name unless log_arguments?

          "#{base_name} with arguments: #{job_data["arguments"]}"
        end

        def perform
          Base.execute(job_data)
        end

        private
          def log_arguments?
            job_data["job_class"].constantize.log_arguments?
          rescue NameError
            false
          end
      end
    end
  end
end
