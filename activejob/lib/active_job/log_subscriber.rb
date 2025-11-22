# frozen_string_literal: true

require "active_support/log_subscriber"

module ActiveJob
  class LogSubscriber < ActiveSupport::EventReporter::LogSubscriber # :nodoc:
    class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

    self.namespace = "active_job"

    def enqueued(event)
      payload = event[:payload]

      if payload[:exception_class]
        error do
          "Failed enqueuing #{payload[:job_class]} to #{queue_name(event)}: #{payload[:exception_class]} (#{payload[:exception_message]})"
        end
      elsif payload[:aborted]
        info do
          "Failed enqueuing #{payload[:job_class]} to #{queue_name(event)}, a before_enqueue callback halted the enqueuing execution."
        end
      else
        info do
          "Enqueued #{payload[:job_class]} (Job ID: #{payload[:job_id]}) to #{queue_name(event)}" + args_info(event)
        end
      end
    end
    event_log_level :enqueued, :info

    def enqueued_at(event)
      payload = event[:payload]

      if payload[:exception_class]
        error do
          "Failed enqueuing #{payload[:job_class]} to #{queue_name(event)}: #{payload[:exception_class]} (#{payload[:exception_message]})"
        end
      elsif payload[:aborted]
        info do
          "Failed enqueuing #{payload[:job_class]} to #{queue_name(event)}, a before_enqueue callback halted the enqueuing execution."
        end
      else
        info do
          "Enqueued #{payload[:job_class]} (Job ID: #{payload[:job_id]}) to #{queue_name(event)} at #{event[:payload][:scheduled_at]}" + args_info(event)
        end
      end
    end
    event_log_level :enqueued_at, :info

    def bulk_enqueued(event)
      payload = event[:payload]

      info do
        if payload[:enqueued_count] == payload[:job_count]
          enqueued_jobs_message(event)
        elsif payload[:enqueued_count] > 0
          if payload[:failed_enqueue_count] == 0
            enqueued_jobs_message(event)
          else
            "#{enqueued_jobs_message(event)}. "\
              "Failed enqueuing #{payload[:failed_enqueue_count]} #{'job'.pluralize(payload[:failed_enqueue_count])}"
          end
        else
          "Failed enqueuing #{payload[:failed_enqueue_count]} #{'job'.pluralize(payload[:failed_enqueue_count])} "\
            "to #{payload[:adapter]}"
        end
      end
    end
    event_log_level :bulk_enqueued, :info

    def started(event)
      payload = event[:payload]

      info do
        enqueue_info = payload[:enqueued_at].present? ? " enqueued at #{payload[:enqueued_at]}" : ""

        "Performing #{payload[:job_class]} (Job ID: #{payload[:job_id]}) from #{queue_name(event)}" + enqueue_info + args_info(event)
      end
    end
    event_log_level :started, :info

    def completed(event)
      payload = event[:payload]

      if payload[:exception_class]
        cleaned_backtrace = backtrace_cleaner.clean(payload[:exception_backtrace])
        error do
          "Error performing #{payload[:job_class]} (Job ID: #{payload[:job_id]}) from #{queue_name(event)} in #{payload[:duration]}ms: #{payload[:exception_class]} (#{payload[:exception_message]}):\n" + Array(cleaned_backtrace).join("\n")
        end
      elsif payload[:aborted]
        error do
          "Error performing #{payload[:job_class]} (Job ID: #{payload[:job_id]}) from #{queue_name(event)} in #{payload[:duration]}ms: a before_perform callback halted the job execution"
        end
      else
        info do
          "Performed #{payload[:job_class]} (Job ID: #{payload[:job_id]}) from #{queue_name(event)} in #{payload[:duration]}ms"
        end
      end
    end
    event_log_level :completed, :info

    def retry_scheduled(event)
      payload = event[:payload]

      info do
        if payload[:exception_class]
          "Retrying #{payload[:job_class]} (Job ID: #{payload[:job_id]}) after #{payload[:executions]} attempts in #{payload[:wait_seconds]} seconds, due to a #{payload[:exception_class]} (#{payload[:exception_message]})."
        else
          "Retrying #{payload[:job_class]} (Job ID: #{payload[:job_id]}) after #{payload[:executions]} attempts in #{payload[:wait_seconds]} seconds."
        end
      end
    end
    event_log_level :retry_scheduled, :info

    def retry_stopped(event)
      payload = event[:payload]

      error do
        "Stopped retrying #{payload[:job_class]} (Job ID: #{payload[:job_id]}) due to a #{payload[:exception_class]} (#{payload[:exception_message]}), which reoccurred on #{payload[:executions]} attempts."
      end
    end
    event_log_level :retry_stopped, :error

    def discarded(event)
      payload = event[:payload]

      error do
        "Discarded #{payload[:job_class]} (Job ID: #{payload[:job_id]}) due to a #{payload[:exception_class]} (#{payload[:exception_message]})."
      end
    end
    event_log_level :discarded, :error

    def interrupt(event)
      payload = event[:payload]

      info do
        "Interrupted #{payload[:job_class]} (Job ID: #{payload[:job_id]}) #{payload[:description]} (#{payload[:reason]})"
      end
    end
    event_log_level :interrupt, :info

    def resume(event)
      payload = event[:payload]

      info do
        "Resuming #{payload[:job_class]} (Job ID: #{payload[:job_id]}) #{payload[:description]}"
      end
    end
    event_log_level :resume, :info

    def step_skipped(event)
      payload = event[:payload]

      info do
        "Step '#{payload[:step]}' skipped #{payload[:job_class]}"
      end
    end
    event_log_level :step_skipped, :info

    def step_started(event)
      payload = event[:payload]

      info do
        if payload[:resumed]
          "Step '#{payload[:step]}' resumed from cursor '#{payload[:cursor]}' for #{payload[:job_class]} (Job ID: #{payload[:job_id]})"
        else
          "Step '#{payload[:step]}' started for #{payload[:job_class]} (Job ID: #{payload[:job_id]})"
        end
      end
    end
    event_log_level :step_started, :info

    def step(event)
      payload = event[:payload]

      if payload[:interrupted]
        info do
          "Step '#{payload[:step]}' interrupted at cursor '#{payload[:cursor]}' for #{payload[:job_class]} (Job ID: #{payload[:job_id]}) in #{payload[:duration]}ms"
        end
      elsif payload[:exception_class]
        error do
          "Error during step '#{payload[:step]}' at cursor '#{payload[:cursor]}' for #{payload[:job_class]} (Job ID: #{payload[:job_id]}) in #{payload[:duration]}ms: #{payload[:exception_class]} (#{payload[:exception_message]})"
        end
      else
        info do
          "Step '#{payload[:step]}' completed for #{payload[:job_class]} (Job ID: #{payload[:job_id]}) in #{payload[:duration]}ms"
        end
      end
    end
    event_log_level :step, :error

    def self.default_logger
      ActiveJob::Base.logger
    end

    private
      def queue_name(event)
        adapter, queue = event[:payload].values_at(:adapter, :queue)
        "#{adapter}(#{queue})"
      end

      def args_info(event)
        if (arguments = event[:payload][:arguments])
          " with arguments: " +
            arguments.map { |arg| format(arg).inspect }.join(", ")
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

      def info(progname = nil, &block)
        return unless super

        if ActiveJob.verbose_enqueue_logs
          log_enqueue_source
        end
      end

      def error(progname = nil, &block)
        return unless super

        if ActiveJob.verbose_enqueue_logs
          log_enqueue_source
        end
      end

      def log_enqueue_source
        source = enqueue_source_location

        if source
          logger.info("↳ #{source}")
        end
      end

      def enqueue_source_location
        backtrace_cleaner.first_clean_frame
      end

      def enqueued_jobs_message(event)
        payload = event[:payload]
        enqueued_count = payload[:enqueued_count]
        job_classes_counts = payload[:enqueued_classes].sort_by { |_k, v| -v }
        "Enqueued #{enqueued_count} #{'job'.pluralize(enqueued_count)} to #{payload[:adapter]}"\
          " (#{job_classes_counts.map { |klass, count| "#{count} #{klass}" }.join(', ')})"
      end
  end
end

ActiveSupport.event_reporter.subscribe(
  ActiveJob::LogSubscriber.new, &ActiveJob::LogSubscriber.subscription_filter
)
