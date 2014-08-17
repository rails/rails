require 'active_support/core_ext/string/filters'
require 'active_support/tagged_logging'
require 'active_support/logger'

module ActiveJob
  module Logging
    extend ActiveSupport::Concern

    included do
      cattr_accessor(:logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT)) }

      around_enqueue do |_, block, _|
        tag_logger do
          block.call
        end
      end

      around_perform do |job, block, _|
        tag_logger(job.class.name, job.job_id) do
          payload = {adapter: job.class.queue_adapter, job: job.class, args: job.arguments}
          ActiveSupport::Notifications.instrument("perform_start.active_job", payload.dup)
          ActiveSupport::Notifications.instrument("perform.active_job", payload) do
            block.call
          end
        end
      end

      before_enqueue do |job|
        if job.enqueued_at
          ActiveSupport::Notifications.instrument "enqueue_at.active_job",
            adapter: job.class.queue_adapter, job: job.class, job_id: job.job_id, args: job.arguments, timestamp: job.enqueued_at
        else
          ActiveSupport::Notifications.instrument "enqueue.active_job",
            adapter: job.class.queue_adapter, job: job.class, job_id: job.job_id, args: job.arguments
        end
      end
    end

    private
      def tag_logger(*tags)
        if logger.respond_to?(:tagged)
          tags.unshift "ActiveJob" unless logger_tagged_by_active_job?
          ActiveJob::Base.logger.tagged(*tags){ yield }
        else
          yield
        end
      end

      def logger_tagged_by_active_job?
        logger.formatter.current_tags.include?("ActiveJob")
      end

    class LogSubscriber < ActiveSupport::LogSubscriber
      def enqueue(event)
        info "Enqueued #{event.payload[:job].name} (Job ID: #{event.payload[:job_id]}) to #{queue_name(event)}" + args_info(event)
      end

      def enqueue_at(event)
        info "Enqueued #{event.payload[:job].name} (Job ID: #{event.payload[:job_id]}) to #{queue_name(event)} at #{enqueued_at(event)}" + args_info(event)
      end

      def perform_start(event)
        info "Performing #{event.payload[:job].name} from #{queue_name(event)}" + args_info(event)
      end

      def perform(event)
        info "Performed #{event.payload[:job].name} from #{queue_name(event)} in #{event.duration.round(2).to_s}ms"
      end

      private
        def queue_name(event)
          event.payload[:adapter].name.demodulize.remove('Adapter') + "(#{event.payload[:job].queue_name})"
        end

        def args_info(event)
          event.payload[:args].any? ? " with arguments: #{event.payload[:args].map(&:inspect).join(", ")}" : ""
        end

        def enqueued_at(event)
          Time.at(event.payload[:timestamp]).utc
        end

        def logger
          ActiveJob::Base.logger
        end
    end
  end
end

ActiveJob::Logging::LogSubscriber.attach_to :active_job
