# frozen_string_literal: true

require "helper"
require "active_support/testing/event_reporter_assertions"
require "active_job/structured_event_subscriber"
require "active_job/continuable"

module ActiveJob
  class StructuredEventSubscriberTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::EventReporterAssertions

    class TestJob < ActiveJob::Base
      def perform(arg = nil)
        case arg
        when "raise_error"
          raise StandardError, "Something went wrong"
        when "discard_error"
          raise StandardError, "Discard this job"
        end
      end
    end

    class RetryJob < ActiveJob::Base
      retry_on StandardError, wait: 1.second, attempts: 3

      def perform
        raise StandardError, "Retry me"
      end
    end

    class DiscardJob < ActiveJob::Base
      discard_on StandardError

      def perform
        raise StandardError, "Discard me"
      end
    end

    class ContinuationJob < ActiveJob::Base
      include ActiveJob::Continuable

      def perform(action:)
        case action
        when :interrupt
          interrupt!(reason: "Interrupted") if executions == 1
        when :step
          step :step do
          end
        when :interrupt_step
          step :interrupt_step do
            interrupt!(reason: "Interrupted") if resumptions.zero?
          end
        when :error_step
          step :error_step do
            raise "Error"
          end
        when :resume
          self.continuation = ActiveJob::Continuation.new(self, "completed" => ["step"])
          continue {  }
        when :skip_step
          self.continuation = ActiveJob::Continuation.new(self, "completed" => ["step"])
          step :step do
          end
        when :resume_step
          self.continuation = ActiveJob::Continuation.new(self, "completed" => [], "current" => ["step", { "job" => self, "resumed" => true }])
          step :step do
          end
        end
      end
    end

    def test_enqueue_job
      event = assert_event_reported("active_job.enqueued", payload: {
        job_class: TestJob.name,
        queue: "default"
      }) do
        TestJob.perform_later
      end

      payload = event[:payload]
      assert payload[:job_id].present?
      assert_empty payload[:arguments]
    end

    def test_enqueue_job_with_arguments
      assert_event_reported("active_job.enqueued", payload: {
        job_class: TestJob.name,
        queue: "default",
        arguments: ["test_arg"]
      }) do
        TestJob.perform_later("test_arg")
      end
    end

    def test_enqueue_job_with_arguments_with_log_arguments_false
      TestJob.log_arguments = false
      event = assert_event_reported("active_job.enqueued", payload: {
        job_class: TestJob.name,
        queue: "default",
      }) do
        TestJob.perform_later("test_arg")
      end

      assert_not event[:payload].key?(:arguments)
    ensure
      TestJob.log_arguments = true
    end

    unless adapter_is?(:inline, :sneakers)
      def test_enqueue_at_job
        scheduled_time = 1.hour.from_now

        event = assert_event_reported("active_job.enqueued", payload: {
          job_class: TestJob.name,
          queue: "default"
        }) do
          TestJob.set(wait_until: scheduled_time).perform_later
        end

        assert event[:payload][:job_id].present?
        assert event[:payload][:scheduled_at].present?
      end
    end

    def test_perform_start_job
      event = assert_event_reported("active_job.started", payload: {
        job_class: TestJob.name,
        queue: "default"
      }) do
        TestJob.perform_now
      end

      assert event[:payload][:job_id].present?
    end

    def test_perform_completed_job
      event = assert_event_reported("active_job.completed", payload: {
        job_class: TestJob.name,
        queue: "default"
      }) do
        TestJob.perform_now
      end

      assert event[:payload][:job_id].present?
      assert event[:payload][:duration].is_a?(Numeric)
    end

    def test_perform_failed_job
      event = assert_event_reported("active_job.completed", payload: {
        job_class: TestJob.name,
        queue: "default",
        exception_class: "StandardError",
        exception_message: "Something went wrong",
      }) do
        assert_raises(StandardError) do
          TestJob.perform_now("raise_error")
        end
      end

      assert event[:payload][:job_id].present?
      assert event[:payload][:duration].is_a?(Numeric)
    end

    def test_enqueue_failed_job
      failing_enqueue_job_class = Class.new(TestJob) do
        before_enqueue do
          raise StandardError, "Enqueue failed"
        end
      end

      assert_event_reported("active_job.enqueued", payload: {
        job_class: failing_enqueue_job_class.name,
        queue: "default",
        exception_class: "StandardError",
        exception_message: "Enqueue failed"
      }) do
        assert_raises(StandardError) do
          failing_enqueue_job_class.perform_later
        end
      end
    end

    def test_enqueue_aborted_job
      aborting_enqueue_job_class = Class.new(TestJob) do
        before_enqueue do
          throw :abort
        end
      end

      assert_event_reported("active_job.enqueued", payload: {
        job_class: aborting_enqueue_job_class.name,
        queue: "default",
        aborted: true,
      }) do
        aborting_enqueue_job_class.perform_later
      end
    end

    def test_perform_aborted_job
      aborting_perform_job_class = Class.new(TestJob) do
        before_perform do
          throw :abort
        end
      end

      assert_event_reported("active_job.completed", payload: {
        job_class: aborting_perform_job_class.name,
        queue: "default",
        aborted: true,
      }) do
        aborting_perform_job_class.perform_now
      end
    end

    unless adapter_is?(:inline, :sneakers)
      def test_retry_scheduled_job
        assert_event_reported("active_job.retry_scheduled", payload: {
          job_class: RetryJob.name,
          executions: 1,
          wait_seconds: 1,
          exception_class: "StandardError",
          exception_message: "Retry me"
        }) do
          assert_raises(StandardError) do
            RetryJob.perform_now
          end
        end
      end
    end

    def test_discard_job
      event = assert_event_reported("active_job.discarded", payload: {
        job_class: DiscardJob.name,
        exception_class: "StandardError",
        exception_message: "Discard me"
      }) do
        DiscardJob.perform_now
      end

      assert event[:payload][:job_id].present?
    end

    def test_bulk_enqueue_jobs
      jobs = [TestJob.new, TestJob.new("arg1"), TestJob.new("arg2")]

      assert_event_reported("active_job.bulk_enqueued", payload: {
        adapter: ActiveJob.adapter_name(ActiveJob::Base.queue_adapter),
        total_jobs: 3,
        enqueued_count: 3,
        failed_count: 0,
        job_classes: { TestJob.name => 3 }
      }) do
        ActiveJob.perform_all_later(jobs)
      end
    end

    unless adapter_is?(:inline, :sneakers)
      def test_interrupt_job
        event = assert_event_reported("active_job.interrupt", payload: {
          job_class: ContinuationJob.name,
          description: "not started",
          reason: "Interrupted"
        }) do
          ContinuationJob.perform_now(action: :interrupt)
        end

        assert event[:payload][:job_id].present?
      end

      def test_resume_job
        event = assert_event_reported("active_job.resume", payload: {
          job_class: ContinuationJob.name,
          description: "after 'step'",
        }) do
          ContinuationJob.perform_now(action: :resume)
        end

        assert event[:payload][:job_id].present?
      end

      def test_step_skipped_job
        event = assert_event_reported("active_job.step_skipped", payload: {
          job_class: ContinuationJob.name,
          step: "step",
        }) do
          ContinuationJob.perform_now(action: :skip_step)
        end

        assert event[:payload][:job_id].present?
      end

      def test_step_resumed_job
        event = assert_event_reported("active_job.step_started", payload: {
          job_class: ContinuationJob.name,
          step: :step,
          resumed: true,
        }) do
          ContinuationJob.perform_later(action: :resume_step)
        end

        assert event[:payload][:job_id].present?
      end

      def test_step_started_job
        event = assert_event_reported("active_job.step_started", payload: {
          job_class: ContinuationJob.name,
          step: :step,
        }) do
          ContinuationJob.perform_now(action: :step)
        end

        assert event[:payload][:job_id].present?
      end

      def test_step_interrupted_job
        event = assert_event_reported("active_job.step", payload: {
          job_class: ContinuationJob.name,
          step: :interrupt_step,
          cursor: nil,
          interrupted: true,
        }) do
          ContinuationJob.perform_now(action: :interrupt_step)
        end

        assert event[:payload][:job_id].present?
        assert event[:payload][:duration].present?
      end

      def test_step_errored_job
        event = assert_event_reported("active_job.step", payload: {
          job_class: ContinuationJob.name,
          step: :error_step,
          cursor: nil,
          exception_class: "RuntimeError",
          exception_message: "Error",
        }) do
          assert_raises(StandardError) do
            ContinuationJob.perform_now(action: :error_step)
          end
        end

        assert event[:payload][:job_id].present?
        assert event[:payload][:duration].present?
      end

      def test_step_job
        event = assert_event_reported("active_job.step", payload: {
          job_class: ContinuationJob.name,
          step: :step,
        }) do
          ContinuationJob.perform_now(action: :step)
        end

        assert event[:payload][:job_id].present?
        assert event[:payload][:duration].present?
      end
    end
  end
end
