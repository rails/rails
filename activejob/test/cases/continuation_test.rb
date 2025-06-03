# frozen_string_literal: true

require "helper"
require "active_job/continuation/test_helper"
require "active_support/testing/stream"
require "active_support/core_ext/object/with"
require "support/test_logger"
require "support/do_not_perform_enqueued_jobs"
require "jobs/continuable_array_cursor_job"
require "jobs/continuable_iterating_job"
require "jobs/continuable_linear_job"
require "jobs/continuable_deleting_job"
require "jobs/continuable_duplicate_step_job"
require "jobs/continuable_nested_steps_job"
require "jobs/continuable_string_step_name_job"
require "jobs/continuable_resume_wrong_step_job"
require "jobs/continuable_nested_cursor_job"

return unless adapter_is?(:test)

class ContinuableJob < ActiveJob::Base
  include ActiveJob::Continuable
end

class ActiveJob::TestContinuation < ActiveSupport::TestCase
  include ActiveJob::Continuation::TestHelper
  include ActiveSupport::Testing::Stream
  include DoNotPerformEnqueuedJobs
  include TestLoggerHelper

  test "iterates" do
    ContinuableIteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| ContinuableIteratingRecord.new(i, "item_#{i}") }

    ContinuableIteratingJob.perform_later

    assert_enqueued_jobs 0, only: ContinuableIteratingJob do
      perform_enqueued_jobs
    end

    assert_equal %w[ new_item_123 new_item_432 new_item_6565 new_item_3243 new_item_234 new_item_13 new_item_22 ], ContinuableIteratingRecord.records.map(&:name)
  end

  test "iterates and continues" do
    ContinuableIteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| ContinuableIteratingRecord.new(i, "item_#{i}") }

    ContinuableIteratingJob.perform_later

    interrupt_job_during_step ContinuableIteratingJob, :rename, cursor: 433 do
      assert_enqueued_jobs 1, only: ContinuableIteratingJob do
        perform_enqueued_jobs
      end
    end

    assert_equal %w[ new_item_123 new_item_432 item_6565 item_3243 new_item_234 new_item_13 new_item_22 ], ContinuableIteratingRecord.records.map(&:name)

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal %w[ new_item_123 new_item_432 new_item_6565 new_item_3243 new_item_234 new_item_13 new_item_22 ], ContinuableIteratingRecord.records.map(&:name)
  end

  test "linear steps" do
    ContinuableLinearJob.items = []
    ContinuableLinearJob.perform_later

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal %w[ item1 item2 item3 item4 ], ContinuableLinearJob.items
  end

  test "linear steps continues from last point" do
    ContinuableLinearJob.items = []
    ContinuableLinearJob.perform_later

    interrupt_job_after_step ContinuableLinearJob, :step_one do
      assert_enqueued_jobs 1, only: ContinuableLinearJob do
        perform_enqueued_jobs
      end
    end

    assert_equal %w[ item1 ], ContinuableLinearJob.items

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal %w[ item1 item2 item3 item4 ], ContinuableLinearJob.items
  end

  test "runs with perform_now" do
    ContinuableLinearJob.items = []
    ContinuableLinearJob.perform_now

    assert_equal %w[ item1 item2 item3 item4 ], ContinuableLinearJob.items
  end

  test "does not retry jobs that error without updating the cursor" do
    ContinuableDeletingJob.items = 10.times.map { |i| "item_#{i}" }
    ContinuableDeletingJob.perform_later

    assert_enqueued_jobs 0, only: ContinuableDeletingJob do
      assert_raises StandardError do
        queue_adapter.with(stopping: ->() { raise StandardError if during_step?(ContinuableDeletingJob, :delete) }) do
          perform_enqueued_jobs
        end
      end
    end

    assert_equal %w[ item_1 item_2 item_3 item_4 item_5 item_6 item_7 item_8 item_9 ], ContinuableDeletingJob.items
  end

  test "saves progress when there is an error" do
    ContinuableIteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| ContinuableIteratingRecord.new(i, "item_#{i}") }

    ContinuableIteratingJob.perform_later

    queue_adapter.with(stopping: ->() { raise StandardError if during_step?(ContinuableIteratingJob, :rename, cursor: 433) }) do
      assert_enqueued_jobs 1, only: ContinuableIteratingJob do
        perform_enqueued_jobs
      end
    end

    job = queue_adapter.enqueued_jobs.first
    assert_equal 1, job["executions"]

    assert_equal %w[ new_item_123 new_item_432 item_6565 item_3243 new_item_234 new_item_13 new_item_22 ], ContinuableIteratingRecord.records.map(&:name)

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal %w[ new_item_123 new_item_432 new_item_6565 new_item_3243 new_item_234 new_item_13 new_item_22 ], ContinuableIteratingRecord.records.map(&:name)
  end

  test "does not retry a second error if the cursor did not advance" do
    ContinuableIteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| ContinuableIteratingRecord.new(i, "item_#{i}") }

    ContinuableIteratingJob.perform_later(raise_when_cursor: 433)

    assert_enqueued_jobs 1, only: ContinuableIteratingJob do
      perform_enqueued_jobs
    end

    job = queue_adapter.enqueued_jobs.first
    assert_equal 1, job["executions"]

    assert_enqueued_jobs 0, only: ContinuableIteratingJob do
      assert_raises StandardError do
        perform_enqueued_jobs
      end
    end
  end

  test "logs interruptions after steps" do
    ContinuableLinearJob.items = []
    ContinuableLinearJob.perform_later

    interrupt_job_after_step ContinuableLinearJob, :step_one do
      perform_enqueued_jobs
      assert_no_match "Resuming", @logger.messages
      assert_match(/Step 'step_one' started/, @logger.messages)
      assert_match(/Step 'step_one' completed/, @logger.messages)
      assert_match(/Interrupted ContinuableLinearJob \(Job ID: [0-9a-f-]{36}\) after 'step_one'/, @logger.messages)
    end

    perform_enqueued_jobs

    assert_match(/Step 'step_one' skipped/, @logger.messages)
    assert_match(/Resuming ContinuableLinearJob \(Job ID: [0-9a-f-]{36}\) after 'step_one'/, @logger.messages)
    assert_match(/Step 'step_two' started/, @logger.messages)
    assert_match(/Step 'step_two' completed/, @logger.messages)
  end

  test "logs interruptions during steps" do
    ContinuableIteratingRecord.records = [ 123, 432, 6565, 3243, 234, 13, 22 ].map { |i| ContinuableIteratingRecord.new(i, "item_#{i}") }
    ContinuableIteratingJob.perform_later

    interrupt_job_during_step ContinuableIteratingJob, :rename, cursor: 433 do
      perform_enqueued_jobs
      assert_no_match "Resuming", @logger.messages
      assert_match(/Step 'rename' started/, @logger.messages)
      assert_match(/Step 'rename' interrupted at cursor '433'/, @logger.messages)
      assert_match(/Interrupted ContinuableIteratingJob \(Job ID: [0-9a-f-]{36}\) at 'rename', cursor '433'/, @logger.messages)
    end

    perform_enqueued_jobs
    assert_match(/Resuming ContinuableIteratingJob \(Job ID: [0-9a-f-]{36}\) at 'rename', cursor '433'/, @logger.messages)
    assert_match(/Step 'rename' resumed from cursor '433'/, @logger.messages)
    assert_match(/Step 'rename' completed/, @logger.messages)
  end

  test "interrupts without cursors" do
    ContinuableDeletingJob.items = 10.times.map { |i| "item_#{i}" }
    ContinuableDeletingJob.perform_later

    interrupt_job_during_step ContinuableDeletingJob, :delete do
      assert_enqueued_jobs 1, only: ContinuableDeletingJob do
        perform_enqueued_jobs
      end
    end

    assert_equal 9, ContinuableDeletingJob.items.count

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal 0, ContinuableDeletingJob.items.count
  end

  test "duplicate steps raise an error" do
    ContinuableDuplicateStepJob.perform_later

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'duplicate' has already been encountered", exception.message
  end

  test "nested steps raise an error" do
    ContinuableNestedStepsJob.perform_later

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'inner_step' is nested inside step 'outer_step'", exception.message
  end

  test "string named steps raise an error" do
    ContinuableStringStepNameJob.perform_later

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'string_step_name' must be a Symbol, found 'String'", exception.message
  end

  test "unexpected step on resumption raises an error" do
    ContinuableResumeWrongStepJob.perform_later

    interrupt_job_during_step ContinuableResumeWrongStepJob, :iterating, cursor: 2 do
      perform_enqueued_jobs
    end

    exception = assert_raises ActiveJob::Continuation::InvalidStepError do
      perform_enqueued_jobs
    end

    assert_equal "Step 'unexpected' found, expected to resume from 'iterating'", exception.message
  end

  class ContinuableAdvancingJob < ContinuableJob
    def perform(start_from, advance_from = nil)
      step :test_step, start: start_from do |step|
        step.advance! from: advance_from
      end
    end
  end

  test "cursor must implement succ to advance" do
    perform_enqueued_jobs do
      assert_raises ActiveJob::Continuation::UnadvanceableCursorError do
        ContinuableAdvancingJob.perform_later(nil)
      end

      assert_raises ActiveJob::Continuation::UnadvanceableCursorError do
        ContinuableAdvancingJob.perform_later(1.1)
      end

      assert_raises ActiveJob::Continuation::UnadvanceableCursorError do
        ContinuableAdvancingJob.perform_later(nil, 1.1)
      end

      assert_nothing_raised do
        ContinuableAdvancingJob.perform_later(1)
      end

      assert_nothing_raised do
        ContinuableAdvancingJob.perform_later(nil, 1)
      end
    end
  end

  test "deserializes a job with no continuation" do
    ContinuableDeletingJob.items = 10.times.map { |i| "item_#{i}" }
    ContinuableDeletingJob.perform_later

    queue_adapter.enqueued_jobs.each { |job| job.delete("continuation") }

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal 0, ContinuableDeletingJob.items.count
  end

  test "nested cursor" do
    ContinuableNestedCursorJob.items = [
      3.times.map { |i| "subitem_0_#{i}" },
      1.times.map { |i| "subitem_1_#{i}" },
      2.times.map { |i| "subitem_2_#{i}" }
    ]
    ContinuableNestedCursorJob.perform_later

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal [ %w[ new_subitem_0_0 new_subitem_0_1 new_subitem_0_2 ], %w[ new_subitem_1_0 ], %w[ new_subitem_2_0 new_subitem_2_1 ] ], ContinuableNestedCursorJob.items
  end

  test "nested cursor resumes" do
    ContinuableNestedCursorJob.items = [
      3.times.map { |i| "subitem_0_#{i}" },
      1.times.map { |i| "subitem_1_#{i}" },
      2.times.map { |i| "subitem_2_#{i}" }
    ]

    ContinuableNestedCursorJob.perform_later

    interrupt_job_during_step ContinuableNestedCursorJob, :updating_sub_items, cursor: [ 0, 2 ] do
      assert_enqueued_jobs 1 do
        perform_enqueued_jobs
      end
    end

    assert_equal [ %w[ new_subitem_0_0 new_subitem_0_1 subitem_0_2 ], %w[ subitem_1_0 ], %w[ subitem_2_0 subitem_2_1 ] ], ContinuableNestedCursorJob.items

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal [ %w[ new_subitem_0_0 new_subitem_0_1 new_subitem_0_2 ], %w[ new_subitem_1_0 ], %w[ new_subitem_2_0 new_subitem_2_1 ] ], ContinuableNestedCursorJob.items
  end

  test "iterates over array cursor" do
    ContinuableArrayCursorJob.items = []

    objects = [ :hello, "world", 1, 1.2, nil, true, false, [ 1, 2, 3 ], { a: 1, b: 2, c: 3 } ]

    ContinuableArrayCursorJob.perform_later(objects)

    assert_enqueued_jobs 0 do
      perform_enqueued_jobs
    end

    assert_equal objects, ContinuableArrayCursorJob.items
  end

  test "interrupts and resumes array cursor" do
    ContinuableArrayCursorJob.items = []

    objects = [ :hello, "world", 1, 1.2, nil, true, false, [ 1, 2, 3 ], { a: 1, b: 2, c: 3 } ]

    ContinuableArrayCursorJob.perform_later(objects)

    assert_enqueued_jobs 1, only: ContinuableArrayCursorJob do
      interrupt_job_during_step ContinuableArrayCursorJob, :iterate_objects, cursor: 3 do
        perform_enqueued_jobs
      end
    end

    assert_equal objects[0...3], ContinuableArrayCursorJob.items

    assert_enqueued_jobs 0, only: ContinuableArrayCursorJob do
      perform_enqueued_jobs
    end

    assert_equal objects, ContinuableArrayCursorJob.items
  end

  private
    def capture_info_stdout(&block)
      ActiveJob::Base.logger.with(level: :info) do
        capture(:stdout, &block)
      end
    end
end
