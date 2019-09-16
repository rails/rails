# frozen_string_literal: true

require "active_support/core_ext/string/filters"
require "active_support/tagged_logging"
require "active_support/logger"

module ActiveJob
  module Logging #:nodoc:
    extend ActiveSupport::Concern

    included do
      cattr_accessor :logger, default: ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))

      around_enqueue do |_, block|
        tag_logger do
          block.call
        end
      end

      around_perform do |job, block|
        tag_logger(job.class.name, job.job_id) do
          payload = { adapter: job.class.queue_adapter, job: job }
          ActiveSupport::Notifications.instrument("perform_start.active_job", payload.dup)
          ActiveSupport::Notifications.instrument("perform.active_job", payload) do
            block.call
          end
        end
      end

      around_enqueue do |job, block|
        if job.scheduled_at
          ActiveSupport::Notifications.instrument("enqueue_at.active_job",
            adapter: job.class.queue_adapter, job: job, &block)
        else
          ActiveSupport::Notifications.instrument("enqueue.active_job",
            adapter: job.class.queue_adapter, job: job, &block)
        end
      end
    end

    private
      def tag_logger(*tags)
        if logger.respond_to?(:tagged)
          tags.unshift "ActiveJob" unless logger_tagged_by_active_job?
          logger.tagged(*tags) { yield }
        else
          yield
        end
      end

      def logger_tagged_by_active_job?
        logger.formatter.current_tags.include?("ActiveJob")
      end
  end
end
