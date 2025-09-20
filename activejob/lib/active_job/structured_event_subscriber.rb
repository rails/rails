# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActiveJob
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    def enqueue(event)
      job = event.payload[:job]
      ex = event.payload[:exception_object] || job.enqueue_error

      if ex
        emit_event("active_job.enqueue_failed",
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name,
          exception_class: ex.class.name,
          exception_message: ex.message
        )
      elsif event.payload[:aborted]
        emit_event("active_job.enqueue_aborted",
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name
        )
      else
        payload = {
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name,
        }
        if job.class.log_arguments?
          payload[:arguments] = job.arguments
        end
        emit_event("active_job.enqueued", payload)
      end
    end

    def enqueue_at(event)
      job = event.payload[:job]
      ex = event.payload[:exception_object] || job.enqueue_error

      if ex
        emit_event("active_job.enqueue_failed",
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name,
          scheduled_at: job.scheduled_at,
          exception_class: ex.class.name,
          exception_message: ex.message
        )
      elsif event.payload[:aborted]
        emit_event("active_job.enqueue_aborted",
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name,
          scheduled_at: job.scheduled_at
        )
      else
        payload = {
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name,
          scheduled_at: job.scheduled_at,
        }
        if job.class.log_arguments?
          payload[:arguments] = job.arguments
        end
        emit_event("active_job.enqueued", payload)
      end
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
      ex = event.payload[:exception_object]

      if ex
        emit_event("active_job.failed",
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name,
          duration_ms: event.duration.round(2),
          exception_class: ex.class.name,
          exception_message: ex.message
        )
      elsif event.payload[:aborted]
        emit_event("active_job.aborted",
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name,
          duration_ms: event.duration.round(2)
        )
      else
        emit_event("active_job.completed",
          job_class: job.class.name,
          job_id: job.job_id,
          queue: job.queue_name,
          duration_ms: event.duration.round(2)
        )
      end
    end

    def enqueue_retry(event)
      job = event.payload[:job]
      ex = event.payload[:error]
      wait = event.payload[:wait]

      emit_event("active_job.retry_scheduled",
        job_class: job.class.name,
        job_id: job.job_id,
        executions: job.executions,
        wait_seconds: wait.to_i,
        exception_class: ex&.class&.name,
        exception_message: ex&.message
      )
    end

    def retry_stopped(event)
      job = event.payload[:job]
      ex = event.payload[:error]

      emit_event("active_job.retry_stopped",
        job_class: job.class.name,
        job_id: job.job_id,
        executions: job.executions,
        exception_class: ex.class.name,
        exception_message: ex.message
      )
    end

    def discard(event)
      job = event.payload[:job]
      ex = event.payload[:error]

      emit_event("active_job.discarded",
        job_class: job.class.name,
        job_id: job.job_id,
        exception_class: ex.class.name,
        exception_message: ex.message
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

      if step.resumed?
        emit_event("active_job.step_resumed",
          job_class: job.class.name,
          job_id: job.job_id,
          step: step.name,
          cursor: step.cursor,
        )
      else
        emit_event("active_job.step_started",
          job_class: job.class.name,
          job_id: job.job_id,
          step: step.name,
        )
      end
    end

    def step(event)
      job = event.payload[:job]
      step = event.payload[:step]
      ex = event.payload[:exception_object]

      if event.payload[:interrupted]
        emit_event("active_job.step_interrupted",
          job_class: job.class.name,
          job_id: job.job_id,
          step: step.name,
          cursor: step.cursor,
          duration: event.duration.round(2),
        )
      elsif ex
        emit_event("active_job.step_errored",
          job_class: job.class.name,
          job_id: job.job_id,
          step: step.name,
          cursor: step.cursor,
          duration: event.duration.round(2),
          exception_class: ex.class.name,
          exception_message: ex.message,
        )
      else
        emit_event("active_job.step",
          job_class: job.class.name,
          job_id: job.job_id,
          step: step.name,
          duration: event.duration.round(2),
        )
      end
    end
  end
end

ActiveJob::StructuredEventSubscriber.attach_to :active_job
