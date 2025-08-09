# frozen_string_literal: true

require "helper"
require "active_job/continuation/test_helper"
require "active_support/testing/stream"
require "active_support/core_ext/object/with"
require "support/test_logger"
require "support/do_not_perform_enqueued_jobs"

return unless adapter_is?(:test)

class ActiveJob::TestContinuation < ActiveSupport::TestCase
  include ActiveJob::Continuation::TestHelper
  include ActiveSupport::Testing::Stream
  include DoNotPerformEnqueuedJobs
  include TestLoggerHelper

  class ContinuableJob < ActiveJob::Base
    include ActiveJob::Continuable
  end

  IteratingRecord = Struct.new(:id, :name) do
    cattr_accessor :records

    def self.find_each(start: nil)
      records.sort_by(&:id).each do |record|
        next if start && record.id < start

        yield record
      end
    end
  end

  class IteratingJob < ContinuableJob
    def perform(raise_when_cursor: nil)
      step :rename do |step|
        IteratingRecord.find_each(start: step.cursor) do |record|
          raise StandardError, "Cursor error" if raise_when_cursor && step.cursor == raise_when_cursor
          record.name = "new_#{record.name}"
          step.advance! from: record.id
        end
      end
    end
  end

  test "iterates" do
    IteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| IteratingRecord.new(i, "item_#{i}") }

    IteratingJob.perform_later

    assert_enqueued_jobs 0, only: IteratingJob do
      perform_enqueued_jobs
    end

    assert_equal %w[ new_item_123 new_item_432 new_item_6565 new_item_3243 new_item_234 new_item_13 new_item_22 ], IteratingRecord.records.map(&:name)
  end

  test "iterates and continues" do
    IteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| IteratingRecord.new(i, "item_#{i}") }

    IteratingJob.perform_later

    interrupt_job_during_step IteratingJob, :rename, cursor: 433 do
      assert_enqueued_jobs 1, only: IteratingJob do
        perform_enqueued_jobs
      end
    end

    assert_equal %w[ new_item_123 new_item_432 item_6565 item_3243 new_item_234 new_item_13 new_item_22 ], IteratingRecord.records.map(&:name)

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal %w[ new_item_123 new_item_432 new_item_6565 new_item_3243 new_item_234 new_item_13 new_item_22 ], IteratingRecord.records.map(&:name)
  end

  class LinearJob < ContinuableJob
    cattr_accessor :items

    def perform
      step :step_one
      step :step_two
      step :step_three
      step :step_four
    end

    private
      def step_one
        items << "item1"
      end

      def step_two
        items << "item2"
      end

      def step_three
        items << "item3"
      end

      def step_four
        items << "item4"
      end
  end

  test "linear steps" do
    LinearJob.items = []
    LinearJob.perform_later

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal %w[ item1 item2 item3 item4 ], LinearJob.items
  end

  test "linear steps continues from last point" do
    LinearJob.items = []
    LinearJob.perform_later

    interrupt_job_after_step LinearJob, :step_one do
      assert_enqueued_jobs 1, only: LinearJob do
        perform_enqueued_jobs
      end
    end

    assert_equal %w[ item1 ], LinearJob.items

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal %w[ item1 item2 item3 item4 ], LinearJob.items
  end

  test "does not checkpoint after the last step" do
    LinearJob.items = []
    LinearJob.perform_later

    interrupt_job_after_step LinearJob, :step_three do
      assert_enqueued_jobs 1, only: LinearJob do
        perform_enqueued_jobs
      end
    end

    interrupt_job_after_step LinearJob, :step_four do
      assert_enqueued_jobs 0, only: LinearJob do
        perform_enqueued_jobs
      end
    end

    assert_equal %w[ item1 item2 item3 item4 ], LinearJob.items
  end

  test "runs with perform_now" do
    LinearJob.items = []
    LinearJob.perform_now

    assert_equal %w[ item1 item2 item3 item4 ], LinearJob.items
  end

  class DeletingJob < ContinuableJob
    cattr_accessor :items

    def perform
      step :delete do |step|
        loop do
          break if items.empty?
          items.shift
          step.checkpoint!
        end
      end
    end
  end

  test "does not retry jobs that error without updating the cursor" do
    DeletingJob.items = 10.times.map { |i| "item_#{i}" }
    DeletingJob.perform_later

    assert_enqueued_jobs 0, only: DeletingJob do
      assert_raises StandardError do
        queue_adapter.with(stopping: ->() { raise StandardError if during_step?(DeletingJob, :delete) }) do
          perform_enqueued_jobs
        end
      end
    end

    assert_equal %w[ item_1 item_2 item_3 item_4 item_5 item_6 item_7 item_8 item_9 ], DeletingJob.items
  end

  test "interrupts without cursors" do
    DeletingJob.items = 10.times.map { |i| "item_#{i}" }
    DeletingJob.perform_later

    interrupt_job_during_step DeletingJob, :delete do
      assert_enqueued_jobs 1, only: DeletingJob do
        perform_enqueued_jobs
      end
    end

    assert_equal 9, DeletingJob.items.count

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal 0, DeletingJob.items.count
  end

  test "saves progress when there is an error" do
    IteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| IteratingRecord.new(i, "item_#{i}") }

    IteratingJob.perform_later

    queue_adapter.with(stopping: ->() { raise StandardError if during_step?(IteratingJob, :rename, cursor: 433) }) do
      assert_enqueued_jobs 1, only: IteratingJob do
        perform_enqueued_jobs
      end
    end

    job = queue_adapter.enqueued_jobs.first
    assert_equal 1, job["executions"]

    assert_equal %w[ new_item_123 new_item_432 item_6565 item_3243 new_item_234 new_item_13 new_item_22 ], IteratingRecord.records.map(&:name)

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal %w[ new_item_123 new_item_432 new_item_6565 new_item_3243 new_item_234 new_item_13 new_item_22 ], IteratingRecord.records.map(&:name)
  end

  test "does not retry a second error if the cursor did not advance" do
    IteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| IteratingRecord.new(i, "item_#{i}") }

    IteratingJob.perform_later(raise_when_cursor: 433)

    assert_enqueued_jobs 1, only: IteratingJob do
      perform_enqueued_jobs
    end

    job = queue_adapter.enqueued_jobs.first
    assert_equal 1, job["executions"]

    assert_enqueued_jobs 0, only: IteratingJob do
      assert_raises StandardError do
        perform_enqueued_jobs
      end
    end
  end

  test "logs interruptions after steps" do
    LinearJob.items = []
    LinearJob.perform_later

    interrupt_job_after_step LinearJob, :step_one do
      perform_enqueued_jobs
      assert_no_match "Resuming", @logger.messages
      assert_match(/Step 'step_one' started/, @logger.messages)
      assert_match(/Step 'step_one' completed/, @logger.messages)
      assert_match(/Interrupted ActiveJob::TestContinuation::LinearJob \(Job ID: [0-9a-f-]{36}\) after 'step_one' \(stopping\)/, @logger.messages)
    end

    perform_enqueued_jobs

    assert_match(/Step 'step_one' skipped/, @logger.messages)
    assert_match(/Resuming ActiveJob::TestContinuation::LinearJob \(Job ID: [0-9a-f-]{36}\) after 'step_one'/, @logger.messages)
    assert_match(/Step 'step_two' started/, @logger.messages)
    assert_match(/Step 'step_two' completed/, @logger.messages)
  end

  test "logs interruptions during steps" do
    IteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| IteratingRecord.new(i, "item_#{i}") }
    IteratingJob.perform_later

    interrupt_job_during_step IteratingJob, :rename, cursor: 433 do
      perform_enqueued_jobs
      assert_no_match "Resuming", @logger.messages
      assert_match(/Step 'rename' started/, @logger.messages)
      assert_match(/Step 'rename' interrupted at cursor '433'/, @logger.messages)
      assert_match(/Interrupted ActiveJob::TestContinuation::IteratingJob \(Job ID: [0-9a-f-]{36}\) at 'rename', cursor '433' \(stopping\)/, @logger.messages)
    end

    perform_enqueued_jobs
    assert_match(/Resuming ActiveJob::TestContinuation::IteratingJob \(Job ID: [0-9a-f-]{36}\) at 'rename', cursor '433'/, @logger.messages)
    assert_match(/Step 'rename' resumed from cursor '433'/, @logger.messages)
    assert_match(/Step 'rename' completed/, @logger.messages)
  end

  class DuplicateStepJob < ContinuableJob
    def perform
      step :duplicate do |step|
      end
      step :duplicate do |step|
      end
    end
  end

  test "duplicate steps raise an error" do
    DuplicateStepJob.perform_later

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'duplicate' has already been encountered", exception.message
  end

  class NestedStepsJob < ContinuableJob
    def perform
      step :outer_step do
        # Not allowed!
        step :inner_step do
        end
      end
    end

    private
      def inner_step; end
  end

  test "nested steps raise an error" do
    NestedStepsJob.perform_later

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'inner_step' is nested inside step 'outer_step'", exception.message
  end

  class StringStepNameJob < ContinuableJob
    def perform
      step "string_step_name" do
      end
    end
  end

  test "string named steps raise an error" do
    StringStepNameJob.perform_later

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'string_step_name' must be a Symbol, found 'String'", exception.message
  end

  class ResumeWrongStepJob < ContinuableJob
    def perform
      if continuation.send(:started?)
        step :unexpected do |step|
        end
      else
        step :iterating, start: 0 do |step|
          ((step.cursor || 1)..4).each do |i|
            step.advance!
          end
        end
      end
    end
  end

  test "unexpected step on resumption raises an error" do
    ResumeWrongStepJob.perform_later

    interrupt_job_during_step ResumeWrongStepJob, :iterating, cursor: 2 do
      perform_enqueued_jobs
    end

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'unexpected' found, expected to resume from 'iterating'", exception.message
  end

  class ChangedStepOrderJob < ContinuableJob
    def perform
      if continuation.send(:started?)
        step :step_one do; end
        step :step_two do; end
        step :step_two_and_a_half do; end
        step :step_three do; end
        step :step_four do; end
      else
        step :step_one do; end
        step :step_two do; end
        step :step_three do; end
        step :step_four do; end
      end
    end
  end

  test "steps not matching previously completed raises an error" do
    ChangedStepOrderJob.perform_later

    interrupt_job_after_step ChangedStepOrderJob, :step_three do
      perform_enqueued_jobs
    end

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'step_two_and_a_half' found, expected to see 'step_three'", exception.message
  end

  class AdvancingJob < ContinuableJob
    def perform(start_from, advance_from = nil)
      step :test_step, start: start_from do |step|
        step.advance! from: advance_from
      end
    end
  end

  test "cursor must implement succ to advance" do
    perform_enqueued_jobs do
      assert_raises ActiveJob::Continuation::UnadvanceableCursorError do
        AdvancingJob.perform_later(nil)
      end

      assert_raises ActiveJob::Continuation::UnadvanceableCursorError do
        AdvancingJob.perform_later(1.1)
      end

      assert_raises ActiveJob::Continuation::UnadvanceableCursorError do
        AdvancingJob.perform_later(nil, 1.1)
      end

      assert_nothing_raised do
        AdvancingJob.perform_later(1)
      end

      assert_nothing_raised do
        AdvancingJob.perform_later(nil, 1)
      end
    end
  end

  test "deserializes a job with no continuation" do
    DeletingJob.items = 10.times.map { |i| "item_#{i}" }
    DeletingJob.perform_later

    queue_adapter.enqueued_jobs.each { |job| job.delete("continuation") }

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal 0, DeletingJob.items.count
  end

  class NestedCursorJob < ContinuableJob
    cattr_accessor :items

    def perform
      step :updating_sub_items, start: [ 0, 0 ] do |step|
        items[step.cursor[0]..].each do |inner_items|
          inner_items[step.cursor[1]..].each do |item|
            items[step.cursor[0]][step.cursor[1]] = "new_#{item}"

            step.set! [ step.cursor[0], step.cursor[1] + 1 ]
          end

          step.set! [ step.cursor[0] + 1, 0 ]
        end
      end
    end
  end

  test "nested cursor" do
    NestedCursorJob.items = [
      3.times.map { |i| "subitem_0_#{i}" },
      1.times.map { |i| "subitem_1_#{i}" },
      2.times.map { |i| "subitem_2_#{i}" }
    ]
    NestedCursorJob.perform_later

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal [ %w[ new_subitem_0_0 new_subitem_0_1 new_subitem_0_2 ], %w[ new_subitem_1_0 ], %w[ new_subitem_2_0 new_subitem_2_1 ] ], NestedCursorJob.items
  end

  test "nested cursor resumes" do
    NestedCursorJob.items = [
      3.times.map { |i| "subitem_0_#{i}" },
      1.times.map { |i| "subitem_1_#{i}" },
      2.times.map { |i| "subitem_2_#{i}" }
    ]

    NestedCursorJob.perform_later

    interrupt_job_during_step NestedCursorJob, :updating_sub_items, cursor: [ 0, 2 ] do
      assert_enqueued_jobs 1 do
        perform_enqueued_jobs
      end
    end

    assert_equal [ %w[ new_subitem_0_0 new_subitem_0_1 subitem_0_2 ], %w[ subitem_1_0 ], %w[ subitem_2_0 subitem_2_1 ] ], NestedCursorJob.items

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal [ %w[ new_subitem_0_0 new_subitem_0_1 new_subitem_0_2 ], %w[ new_subitem_1_0 ], %w[ new_subitem_2_0 new_subitem_2_1 ] ], NestedCursorJob.items
  end

  class ArrayCursorJob < ContinuableJob
    cattr_accessor :items, default: []

    def perform(objects)
      step :iterate_objects, start: 0 do |step|
        objects[step.cursor..].each do |object|
          items << object
          step.advance!
        end
      end
    end
  end

  test "iterates over array cursor" do
    ArrayCursorJob.items = []

    objects = [ :hello, "world", 1, 1.2, nil, true, false, [ 1, 2, 3 ], { a: 1, b: 2, c: 3 } ]

    ArrayCursorJob.perform_later(objects)

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal objects, ArrayCursorJob.items
  end

  test "interrupts and resumes array cursor" do
    ArrayCursorJob.items = []

    objects = [ :hello, "world", 1, 1.2, nil, true, false, [ 1, 2, 3 ], { a: 1, b: 2, c: 3 } ]

    ArrayCursorJob.perform_later(objects)

    assert_enqueued_jobs 1, only: ArrayCursorJob do
      interrupt_job_during_step ArrayCursorJob, :iterate_objects, cursor: 3 do
        perform_enqueued_jobs
      end
    end

    assert_equal objects[0...3], ArrayCursorJob.items

    assert_enqueued_jobs 0, only: ArrayCursorJob do
      perform_enqueued_jobs
    end

    assert_equal objects, ArrayCursorJob.items
  end

  class LimitedResumesJob < ContinuableJob
    self.max_resumptions = 2

    def perform(iterations)
      step :iterate, start: 0 do |step|
        (step.cursor..iterations).each do |i|
          step.advance!
        end
      end
    end
  end

  test "limits resumes" do
    LimitedResumesJob.perform_later(10)

    interrupt_job_during_step LimitedResumesJob, :iterate, cursor: 1 do
      assert_enqueued_jobs 1, only: LimitedResumesJob do
        perform_enqueued_jobs
      end
    end

    interrupt_job_during_step LimitedResumesJob, :iterate, cursor: 2 do
      assert_enqueued_jobs 1, only: LimitedResumesJob do
        perform_enqueued_jobs
      end
    end

    interrupt_job_during_step LimitedResumesJob, :iterate, cursor: 3 do
      assert_enqueued_jobs 0, only: LimitedResumesJob do
        exception = assert_raises ActiveJob::Continuation::ResumeLimitError do
          perform_enqueued_jobs
        end

        assert_equal "Job was resumed a maximum of 2 times", exception.message
      end
    end
  end

  test "limits resumes due to errors" do
    LimitedResumesJob.perform_later(10)

    queue_adapter.with(stopping: ->() { raise StandardError if during_step?(LimitedResumesJob, :iterate, cursor: 1) }) do
      assert_enqueued_jobs 1, only: LimitedResumesJob do
        perform_enqueued_jobs
      end
    end

    queue_adapter.with(stopping: ->() { raise StandardError if during_step?(LimitedResumesJob, :iterate, cursor: 2) }) do
      assert_enqueued_jobs 1, only: LimitedResumesJob do
        perform_enqueued_jobs
      end
    end

    queue_adapter.with(stopping: ->() { raise StandardError if during_step?(LimitedResumesJob, :iterate, cursor: 3) }) do
      assert_enqueued_jobs 0, only: LimitedResumesJob do
        exception = assert_raises ActiveJob::Continuation::ResumeLimitError do
          perform_enqueued_jobs
        end

        assert_equal "Job was resumed a maximum of 2 times", exception.message
      end
    end
  end

  test "does not resume after an error" do
    LimitedResumesJob.with(resume_errors_after_advancing: false) do
      LimitedResumesJob.perform_later(10)

      queue_adapter.with(stopping: ->() { raise StandardError, "boom" if during_step?(LimitedResumesJob, :iterate, cursor: 5) }) do
        assert_enqueued_jobs 0, only: LimitedResumesJob do
          exception = assert_raises StandardError do
            perform_enqueued_jobs
          end

          assert_equal "boom", exception.message
        end
      end
    end
  end

  test "resume options" do
    LimitedResumesJob.with(resume_options: { queue: :other, wait: 8 }) do
      freeze_time

      LimitedResumesJob.perform_later(10)

      interrupt_job_during_step LimitedResumesJob, :iterate, cursor: 1 do
        assert_enqueued_with job: LimitedResumesJob, queue: :other, at: Time.now + 8.seconds do
          perform_enqueued_jobs
        end
      end
    end
  end

  class IsolatedStepsJob < ContinuableJob
    cattr_accessor :items, default: []

    def perform(*isolated)
      step :step_one, isolated: isolated.include?(:step_one) do |step|
        items << "step_one"
      end
      step :step_two, isolated: isolated.include?(:step_two) do |step|
        items << "step_two"
      end
      step :step_three, isolated: isolated.include?(:step_three) do |step|
        items << "step_three"
      end
      step :step_four, isolated: isolated.include?(:step_four) do |step|
        items << "step_four"
      end
    end
  end

  test "runs isolated step separately" do
    IsolatedStepsJob.items = []
    IsolatedStepsJob.perform_later(:step_three)

    assert_enqueued_jobs 1, only: IsolatedStepsJob do
      perform_enqueued_jobs
    end

    assert_equal [ "step_one", "step_two" ], IsolatedStepsJob.items

    assert_enqueued_jobs 1 do
      perform_enqueued_jobs
    end

    assert_equal [ "step_one", "step_two", "step_three" ], IsolatedStepsJob.items

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal [ "step_one", "step_two", "step_three", "step_four" ], IsolatedStepsJob.items
    assert_match(/Interrupted ActiveJob::TestContinuation::IsolatedStepsJob \(Job ID: [0-9a-f-]{36}\) after 'step_two' \(isolating\)/, @logger.messages)
    assert_match(/Interrupted ActiveJob::TestContinuation::IsolatedStepsJob \(Job ID: [0-9a-f-]{36}\) after 'step_three' \(isolating\)/, @logger.messages)
  end

  test "runs initial and final isolated steps separately" do
    IsolatedStepsJob.items = []
    IsolatedStepsJob.perform_later(:step_one, :step_four)

    assert_enqueued_jobs 1, only: IsolatedStepsJob do
      perform_enqueued_jobs
    end

    assert_equal [ "step_one" ], IsolatedStepsJob.items

    assert_enqueued_jobs 1 do
      perform_enqueued_jobs
    end

    assert_equal [ "step_one", "step_two", "step_three" ], IsolatedStepsJob.items

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal [ "step_one", "step_two", "step_three", "step_four" ], IsolatedStepsJob.items
  end

  private
    def capture_info_stdout(&block)
      ActiveJob::Base.logger.with(level: :info) do
        capture(:stdout, &block)
      end
    end
end
