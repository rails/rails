# frozen_string_literal: true

gem "sidekiq", ">= 4.1.0"
require "sidekiq"

module ActiveJob
  module QueueAdapters
    # = Sidekiq adapter for Active Job
    #
    # Simple, efficient background processing for Ruby. Sidekiq uses threads to
    # handle many jobs at the same time in the same process. It does not
    # require \Rails but will integrate tightly with it to make background
    # processing dead simple.
    #
    # Read more about Sidekiq {here}[http://sidekiq.org].
    #
    # To use Sidekiq set the queue_adapter config to +:sidekiq+.
    #
    #   Rails.application.config.active_job.queue_adapter = :sidekiq
    class SidekiqAdapter < AbstractAdapter
      def enqueue(job) # :nodoc:
        job.provider_job_id = JobWrapper.set(
          wrapped: job.class,
          queue: job.queue_name
        ).perform_async(job.serialize)
      end

      def enqueue_at(job, timestamp) # :nodoc:
        job.provider_job_id = JobWrapper.set(
          wrapped: job.class,
          queue: job.queue_name,
        ).perform_at(timestamp, job.serialize)
      end

      def enqueue_all(jobs) # :nodoc:
        enqueued_count = 0
        jobs.group_by(&:class).each do |job_class, same_class_jobs|
          same_class_jobs.group_by(&:queue_name).each do |queue, same_class_and_queue_jobs|
            immediate_jobs, scheduled_jobs = same_class_and_queue_jobs.partition { |job| job.scheduled_at.nil? }

            if immediate_jobs.any?
              jids = Sidekiq::Client.push_bulk(
                "class" => JobWrapper,
                "wrapped" => job_class,
                "queue" => queue,
                "args" => immediate_jobs.map { |job| [job.serialize] },
              )
              enqueued_count += jids.compact.size
            end

            if scheduled_jobs.any?
              jids = Sidekiq::Client.push_bulk(
                "class" => JobWrapper,
                "wrapped" => job_class,
                "queue" => queue,
                "args" => scheduled_jobs.map { |job| [job.serialize] },
                "at" => scheduled_jobs.map { |job| job.scheduled_at&.to_f }
              )
              enqueued_count += jids.compact.size
            end
          end
        end
        enqueued_count
      end

      class JobWrapper # :nodoc:
        include Sidekiq::Worker

        def perform(job_data)
          Base.execute job_data.merge("provider_job_id" => jid)
        end
      end
    end
  end
end
