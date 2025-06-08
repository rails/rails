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
      def initialize(*) # :nodoc:
        @stopping = false

        Sidekiq.configure_server do |config|
          config.on(:quiet) { @stopping = true }
        end

        Sidekiq.configure_client do |config|
          config.on(:quiet) { @stopping = true }
        end
      end

      delegate :enqueue, :enqueue_at, :enqueue_all, to: Sidekiq::ActiveJob::QueueAdapters::SidekiqAdapter

      def enqueue_after_transaction_commit? = true

      JobWrapper = Sidekiq::ActiveJob::Wrapper
    end
  end
end
