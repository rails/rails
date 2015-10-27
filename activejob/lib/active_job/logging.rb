require 'active_support/core_ext/hash/transform_values'
require 'active_support/core_ext/string/filters'
require 'active_support/tagged_logging'
require 'active_support/logger'

module ActiveJob
  module Logging #:nodoc:
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
          payload = {adapter: job.class.queue_adapter, job: job}
          ActiveSupport::Notifications.instrument("perform_start.active_job", payload.dup)
          ActiveSupport::Notifications.instrument("perform.active_job", payload) do
            block.call
          end
        end
      end

      after_enqueue do |job|
        if job.scheduled_at
          ActiveSupport::Notifications.instrument "enqueue_at.active_job",
            adapter: job.class.queue_adapter, job: job
        else
          ActiveSupport::Notifications.instrument "enqueue.active_job",
            adapter: job.class.queue_adapter, job: job
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

    class LogSubscriber < ActiveSupport::LogSubscriber #:nodoc:
      def enqueue(event)
        job = event.payload[:job]

        info do
          "Enqueued #{job.class.name} (Job ID: #{job.job_id}) to #{queue_name(event)}"
        end

        log_args_info(job)
      end

      def enqueue_at(event)
        job = event.payload[:job]

        info do
          "Enqueued #{job.class.name} (Job ID: #{job.job_id}) to #{queue_name(event)} at #{scheduled_at(event)}"
        end

        log_args_info(job)
      end

      def perform_start(event)
        job = event.payload[:job]

        info do
          "Performing #{job.class.name} from #{queue_name(event)}"
        end

        log_args_info(job)
      end

      def perform(event)
        info do
          job = event.payload[:job]
          "Performed #{job.class.name} from #{queue_name(event)} in #{event.duration.round(2)}ms"
        end
      end

      private
        def queue_name(event)
          event.payload[:adapter].class.name.demodulize.remove('Adapter') + "(#{event.payload[:job].queue_name})"
        end

        def log_args_info(job)
          if job.arguments.any?
            debug do
              arguments = job.arguments.map { |arg| format(arg).inspect }.join(', ')
              "Job ID: #{job.job_id} arguments: " + arguments
            end
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
