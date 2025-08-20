# frozen_string_literal: true

require "active_support/core_ext/numeric/time"
require "active_job/continuable"

module ActiveJob
  # = Active Job \Continuation
  #
  # Continuations provide a mechanism for interrupting and resuming jobs. This allows
  # long-running jobs to make progress across application restarts.
  #
  # Jobs should include the ActiveJob::Continuable module to enable continuations.
  # \Continuable jobs are automatically retried when interrupted.
  #
  # Use the +step+ method to define the steps in your job. Steps can use an optional
  # cursor to track progress in the step.
  #
  # Steps are executed as soon as they are encountered. If a job is interrupted, previously
  # completed steps will be skipped. If a step is in progress, it will be resumed
  # with the last recorded cursor.
  #
  # Code that is not part of a step will be executed on each job run.
  #
  # You can pass a block or a method name to the step method. The block will be called with
  # the step object as an argument. Methods can either take no arguments or a single argument
  # for the step object.
  #
  #   class ProcessImportJob < ApplicationJob
  #     include ActiveJob::Continuable
  #
  #     def perform(import_id)
  #       # This always runs, even if the job is resumed.
  #       @import = Import.find(import_id)
  #
  #       step :validate do
  #         @import.validate!
  #       end
  #
  #       step(:process_records) do |step|
  #         @import.records.find_each(start: step.cursor) do |record|
  #           record.process
  #           step.advance! from: record.id
  #         end
  #       end
  #
  #       step :reprocess_records
  #       step :finalize
  #     end
  #
  #     def reprocess_records(step)
  #       @import.records.find_each(start: step.cursor) do |record|
  #         record.reprocess
  #         step.advance! from: record.id
  #       end
  #     end
  #
  #     def finalize
  #       @import.finalize!
  #     end
  #   end
  #
  # === Cursors
  #
  # Cursors are used to track progress within a step. The cursor can be any object that is
  # serializable as an argument to +ActiveJob::Base.serialize+. It defaults to +nil+.
  #
  # When a step is resumed, the last cursor value is restored. The code in the step is responsible
  # for using the cursor to continue from the right point.
  #
  # +set!+ sets the cursor to a specific value.
  #
  #   step :iterate_items do |step|
  #     items[step.cursor..].each do |item|
  #       process(item)
  #       step.set! (step.cursor || 0) + 1
  #     end
  #   end
  #
  # An starting value for the cursor can be set when defining the step:
  #
  #   step :iterate_items, start: 0 do |step|
  #     items[step.cursor..].each do |item|
  #       process(item)
  #       step.set! step.cursor + 1
  #     end
  #   end
  #
  # The cursor can be advanced with +advance!+. This calls +succ+ on the current cursor value.
  # It raises an ActiveJob::Continuation::UnadvanceableCursorError if the cursor does not implement +succ+.
  #
  #   step :iterate_items, start: 0 do |step|
  #     items[step.cursor..].each do |item|
  #       process(item)
  #       step.advance!
  #     end
  #   end
  #
  # You can optionally pass a +from+ argument to +advance!+. This is useful when iterating
  # over a collection of records where IDs may not be contiguous.
  #
  #   step :process_records do |step|
  #     import.records.find_each(start: step.cursor) do |record|
  #       record.process
  #       step.advance! from: record.id
  #     end
  #   end
  #
  # You can use an array to iterate over nested records:
  #
  #   step :process_nested_records, start: [ 0, 0 ] do |step|
  #     Account.find_each(start: step.cursor[0]) do |account|
  #       account.records.find_each(start: step.cursor[1]) do |record|
  #         record.process
  #         step.set! [ account.id, record.id + 1 ]
  #       end
  #       step.set! [ account.id + 1, 0 ]
  #     end
  #   end
  #
  # Setting or advancing the cursor creates a checkpoint. You can also create a checkpoint
  # manually by calling the +checkpoint!+ method on the step. This is useful if you want to
  # allow interruptions, but don't need to update the cursor.
  #
  #   step :destroy_records do |step|
  #     import.records.find_each do |record|
  #       record.destroy!
  #       step.checkpoint!
  #     end
  #   end
  #
  # === Checkpoints
  #
  # A checkpoint is where a job can be interrupted. At a checkpoint the job will call
  # +queue_adapter.stopping?+. If it returns true, the job will raise an
  # ActiveJob::Continuation::Interrupt exception.
  #
  # There is an automatic checkpoint before the start of each step except for the first for
  # each job execution. Within a step one is created when calling +set!+, +advance!+ or +checkpoint!+.
  #
  # Jobs are not automatically interrupted when the queue adapter is marked as stopping - they
  # will continue to run either until the next checkpoint, or when the process is stopped.
  #
  # This is to allow jobs to be interrupted at a safe point, but it also means that the jobs
  # should checkpoint more frequently than the shutdown timeout to ensure a graceful restart.
  #
  # When interrupted, the job will automatically retry with the progress serialized
  # in the job data under the +continuation+ key.
  #
  # The serialized progress contains:
  # - a list of the completed steps
  # - the current step and its cursor value (if one is in progress)
  #
  # === Isolated Steps
  #
  # Steps run sequentially in a single job execution, unless the job is interrupted.
  #
  # You can specify that a step should always run in its own execution by passing the +isolated: true+ option.
  #
  # This is useful for long-running steps where it may not be possible to checkpoint within
  # the job grace period - it ensures that progress is serialized back into the job data before
  # the step starts.
  #
  #   step :quick_step1
  #   step :slow_step, isolated: true
  #   step :quick_step2
  #   step :quick_step3
  #
  # === Errors
  #
  # If a job raises an error and is not retried via Active Job, it will be passed back to the underlying
  # queue backend and any progress in this execution will be lost.
  #
  # To mitigate this, the job will be automatically retried if it raises an error after it has made progress.
  # Making progress is defined as having completed a step or advanced the cursor within the current step.
  #
  # === Configuration
  #
  # Continuable jobs have several configuration options:
  # * <tt>:max_resumptions</tt> - The maximum number of times a job can be resumed. Defaults to +nil+ which means
  #   unlimited resumptions.
  # * <tt>:resume_options</tt> - Options to pass to +retry_job+ when resuming the job.
  #   Defaults to <tt>{ wait: 5.seconds }</tt>.
  #   See {ActiveJob::Exceptions#retry_job}[rdoc-ref:ActiveJob::Exceptions#retry_job] for available options.
  # * <tt>:resume_errors_after_advancing</tt> - Whether to resume errors after advancing the continuation.
  #   Defaults to +true+.
  class Continuation
    extend ActiveSupport::Autoload

    autoload :Validation

    # Raised when a job is interrupted, allowing Active Job to requeue it.
    # This inherits from +Exception+ rather than +StandardError+, so it's not
    # caught by normal exception handling.
    class Interrupt < Exception; end

    # Base class for all Continuation errors.
    class Error < StandardError; end

    # Raised when a step is invalid.
    class InvalidStepError < Error; end

    # Raised when there is an error with a checkpoint, such as open database transactions.
    class CheckpointError < Error; end

    # Raised when attempting to advance a cursor that doesn't implement `succ`.
    class UnadvanceableCursorError < Error; end

    # Raised when a job has reached its limit of the number of resumes.
    # The limit is defined by the +max_resumes+ class attribute.
    class ResumeLimitError < Error; end

    include Validation

    def initialize(job, serialized_progress) # :nodoc:
      @job = job
      @completed = serialized_progress.fetch("completed", []).map(&:to_sym)
      @current = new_step(*serialized_progress["current"], resumed: true) if serialized_progress.key?("current")
      @encountered = []
      @advanced = false
      @running_step = false
      @isolating = false
    end

    def step(name, **options, &block) # :nodoc:
      validate_step!(name)
      encountered << name

      if completed?(name)
        skip_step(name)
      else
        run_step(name, **options, &block)
      end
    end

    def to_h # :nodoc:
      {
        "completed" => completed.map(&:to_s),
        "current" => current&.to_a,
      }.compact
    end

    def description # :nodoc:
      if current
        current.description
      elsif completed.any?
        "after '#{completed.last}'"
      else
        "not started"
      end
    end

    def started?
      completed.any? || current.present?
    end

    def advanced?
      @advanced
    end

    def instrumentation
      { description: description,
        completed_steps: completed,
        current_step: current }
    end

    private
      attr_reader :job, :encountered, :completed, :current

      def running_step?
        @running_step
      end

      def isolating?
        @isolating
      end

      def completed?(name)
        completed.include?(name)
      end

      def new_step(*args, **options)
        Step.new(*args, job: job, **options)
      end

      def skip_step(name)
        instrument :step_skipped, step: name
      end

      def run_step(name, start:, isolated:, &block)
        @isolating ||= isolated

        if isolating? && advanced?
          job.interrupt!(reason: :isolating)
        else
          run_step_inline(name, start: start, &block)
        end
      end

      def run_step_inline(name, start:, **options, &block)
        @running_step = true
        @current ||= new_step(name, start, resumed: false)

        instrumenting_step(current) do
          block.call(current)
        end

        @completed << current.name
        @current = nil
        @advanced = true
      ensure
        @running_step = false
        @advanced ||= current&.advanced?
      end

      def instrumenting_step(step, &block)
        instrument :step, step: step, interrupted: false do |payload|
          instrument :step_started, step: step

          block.call
        rescue Interrupt
          payload[:interrupted] = true
          raise
        end
      end

      def instrument(...)
        job.instrument(...)
      end
  end
end

require "active_job/continuation/step"
