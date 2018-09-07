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

      class LogSubscriber < ActiveSupport::LogSubscriber #:nodoc:
        def enqueue(event)
          info do
            job = event.payload[:job]
            "Enqueued #{job.class.name} (Job ID: #{job.job_id}) to #{queue_name(event)}" + args_info(job)
          end
        end

        def enqueue_at(event)
          info do
            job = event.payload[:job]
            "Enqueued #{job.class.name} (Job ID: #{job.job_id}) to #{queue_name(event)} at #{scheduled_at(event)}" + args_info(job)
          end
        end

        def perform_start(event)
          info do
            job = event.payload[:job]
            "Performing #{job.class.name} (Job ID: #{job.job_id}) from #{queue_name(event)}" + args_info(job)
          end
        end

        def perform(event)
          job = event.payload[:job]
          ex = event.payload[:exception_object]
          if ex
            error do
              "Error performing #{job.class.name} (Job ID: #{job.job_id}) from #{queue_name(event)} in #{event.duration.round(2)}ms: #{ex.class} (#{ex.message}):\n" + Array(ex.backtrace).join("\n")
            end
          else
            info do
              "Performed #{job.class.name} (Job ID: #{job.job_id}) from #{queue_name(event)} in #{event.duration.round(2)}ms"
            end
          end
        end

        def enqueue_retry(event)
          job = event.payload[:job]
          ex = event.payload[:error]
          wait = event.payload[:wait]

          error do
            "Retrying #{job.class} in #{wait} seconds, due to a #{ex.class}. The original exception was #{ex.cause.inspect}."
          end
        end

        def retry_stopped(event)
          job = event.payload[:job]
          ex = event.payload[:error]

          error do
            "Stopped retrying #{job.class} due to a #{ex.class}, which reoccurred on #{job.executions} attempts. The original exception was #{ex.cause.inspect}."
          end
        end

        def discard(event)
          job = event.payload[:job]
          ex = event.payload[:error]

          error do
            "Discarded #{job.class} due to a #{ex.class}. The original exception was #{ex.cause.inspect}."
          end
        end

        private
          def queue_name(event)
            event.payload[:adapter].class.name.demodulize.remove("Adapter") + "(#{event.payload[:job].queue_name})"
          end

          def args_info(job)
            if job.arguments.any?
              " with arguments: " +
                job.arguments.map { |arg| format(arg).inspect }.join(", ")
            else
              ""
            end
          end

          def format(arg)
            case arg
            when Hash
              arg.transform_values { |value| format(value) }
            when Array
              arg.map { |value| format(value) }
            when GlobalID::Identification
              arg.to_global_id rescue arg
            else
              arg
            end
          end

          def scheduled_at(event)
            Time.at(event.payload[:job].scheduled_at).utc
          end

          def logger
            ActiveJob::Base.logger
          end
      end
  end
end

ActiveJob::Logging::LogSubscriber.attach_to :active_job
