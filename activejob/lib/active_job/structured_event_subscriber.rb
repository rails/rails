# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActiveJob
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    def enqueue(event)
      job = event.payload[:job]
      exception = event.payload[:exception_object] || job.enqueue_error
      payload = {
        job_class: job.class.name,
        job_id: job.job_id,
        queue: job.queue_name,
        aborted: event.payload[:aborted],
      }

      if exception
        payload[:exception_class] = exception.class.name
        payload[:exception_message] = exception.message
      end

      if job.class.log_arguments?
        payload[:arguments] = job.arguments
      end

      emit_event("active_job.enqueued", payload)
    end

    def enqueue_at(event)
      job = event.payload[:job]
      exception = event.payload[:exception_object] || job.enqueue_error
      payload = {
        job_class: job.class.name,
        job_id: job.job_id,
        queue: job.queue_name,
        scheduled_at: job.scheduled_at,
        aborted: event.payload[:aborted],
      }

      if exception
        payload[:exception_class] = exception.class.name
        payload[:exception_message] = exception.message
      end

      if job.class.log_arguments?
        payload[:arguments] = job.arguments
      end

      emit_event("active_job.enqueued", payload)
    end

    def enqueue_all(event)
      jobs = event.payload[:jobs]
      adapter = event.payload[:adapter]
      enqueued_count = event.payload[:enqueued_count].to_i
      failed_count = jobs.size - enqueued_count

      emit_event("active_job.bulk_enqueued",
        adapter: ActiveJob.adapter_name(adapter),
        total_jobs: jobs.size,
        enqueued_count: enqueued_count,
        failed_count: failed_count,
        job_classes: jobs.map { |job| job.class.name }.tally
      )
    end

    def perform_start(event)
      job = event.payload[:job]
      payload = {
        job_class: job.class.name,
        job_id: job.job_id,
        queue: job.queue_name,
        enqueued_at: job.enqueued_at&.utc&.iso8601(9),
      }
      if job.class.log_arguments?
        payload[:arguments] = job.arguments
      end
      emit_event("active_job.started", payload)
    end

    def perform(event)
      job = event.payload[:job]
      exception = event.payload[:exception_object]
      payload = {
        job_class: job.class.name,
        job_id: job.job_id,
        queue: job.queue_name,
        aborted: event.payload[:aborted],
        duration: event.duration.round(2),
      }

      if exception
        payload[:exception_class] = exception.class.name
        payload[:exception_message] = exception.message
      end

      emit_event("active_job.completed", payload)
    end

    def enqueue_retry(event)
      job = event.payload[:job]
      exception = event.payload[:error]
      wait = event.payload[:wait]

      emit_event("active_job.retry_scheduled",
        job_class: job.class.name,
        job_id: job.job_id,
        executions: job.executions,
        wait_seconds: wait.to_i,
        exception_class: exception&.class&.name,
        exception_message: exception&.message
      )
    end

    def retry_stopped(event)
      job = event.payload[:job]
      exception = event.payload[:error]

      emit_event("active_job.retry_stopped",
        job_class: job.class.name,
        job_id: job.job_id,
        executions: job.executions,
        exception_class: exception.class.name,
        exception_message: exception.message
      )
    end

    def discard(event)
      job = event.payload[:job]
      exception = event.payload[:error]

      emit_event("active_job.discarded",
        job_class: job.class.name,
        job_id: job.job_id,
        exception_class: exception.class.name,
        exception_message: exception.message
      )
    end

    def interrupt(event)
      job = event.payload[:job]
      description = event.payload[:description]
      reason = event.payload[:reason]

      emit_event("active_job.interrupt",
        job_class: job.class.name,
        job_id: job.job_id,
        description: description,
        reason: reason,
      )
    end

    def resume(event)
      job = event.payload[:job]
      description = event.payload[:description]

      emit_event("active_job.resume",
        job_class: job.class.name,
        job_id: job.job_id,
        description: description,
      )
    end

    def step_skipped(event)
      job = event.payload[:job]
      step = event.payload[:step]

      emit_event("active_job.step_skipped",
        job_class: job.class.name,
        job_id: job.job_id,
        step: step.name,
      )
    end

    def step_started(event)
      job = event.payload[:job]
      step = event.payload[:step]

      emit_event("active_job.step_started",
        job_class: job.class.name,
        job_id: job.job_id,
        step: step.name,
        cursor: step.cursor,
        resumed: step.resumed?,
      )
    end

    def step(event)
      job = event.payload[:job]
      step = event.payload[:step]
      exception = event.payload[:exception_object]
      payload = {
        job_class: job.class.name,
        job_id: job.job_id,
        step: step.name,
        cursor: step.cursor,
        interrupted: event.payload[:interrupted],
        duration: event.duration.round(2),
      }

      if exception
        payload[:exception_class] = exception.class.name
        payload[:exception_message] = exception.message
      end

      emit_event("active_job.step", payload)
    end
  end
end

ActiveJob::StructuredEventSubscriber.attach_to :active_job
