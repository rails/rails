# frozen_string_literal: true

require "helper"
require "jobs/enqueue_error_job"

class EnqueueAfterTransactionCommitTest < ActiveSupport::TestCase
  class FakeActiveRecord
    attr_reader :calls

    def initialize(should_yield = true)
      @calls = 0
      @yield = should_yield
      @callbacks = []
    end

    def after_all_transactions_commit(&block)
      @calls += 1
      if @yield
        yield
      else
        @callbacks << block
      end
    end

    def run_after_commit_callbacks
      callbacks, @callbacks = @callbacks, []
      callbacks.each(&:call)
    end
  end

  class ImmediateJob < ActiveJob::Base
    self.enqueue_after_transaction_commit = false

    def perform
      # noop
    end
  end

  class TestJob < ActiveJob::Base
    def perform
      # noop
    end
  end

  class ErrorTestJob < EnqueueErrorJob
    class EnqueueErrorAdapter
      def enqueue(...)
        raise ActiveJob::EnqueueError, "There was an error enqueuing the job"
      end

      def enqueue_at(...)
        raise ActiveJob::EnqueueError, "There was an error enqueuing the job"
      end
    end

    self.queue_adapter = EnqueueErrorAdapter.new

    def perform
      # noop
    end
  end

  class CallbackTestJob < ActiveJob::Base
    attr_reader :around_enqueue_called

    around_enqueue do |job, block|
      job.instance_variable_set(:@around_enqueue_called, true)
      block.call
    end

    def perform
      # noop
    end
  end

  test "#perform_later wait for transactions to complete before enqueuing the job" do
    fake_active_record = FakeActiveRecord.new
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      TestJob.enqueue_after_transaction_commit = true

      assert_difference -> { fake_active_record.calls }, +1 do
        TestJob.perform_later
      end
    end
  end

  test "#perform_later returns the Job instance even if it's delayed by `after_all_transactions_commit`" do
    fake_active_record = FakeActiveRecord.new(false)
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      TestJob.enqueue_after_transaction_commit = true

      job = TestJob.perform_later
      assert_instance_of TestJob, job
      assert_predicate job, :successfully_enqueued?
    end
  end

  test "#perform_later yields the enqueued Job instance even if it's delayed by `after_all_transactions_commit`" do
    fake_active_record = FakeActiveRecord.new(false)
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      TestJob.enqueue_after_transaction_commit = true

      called = false
      job = TestJob.perform_later do |yielded_job|
        called = true
        assert_instance_of TestJob, yielded_job
      end
      assert called, "#perform_later yielded the job"
      assert_instance_of TestJob, job
      assert_predicate job, :successfully_enqueued?
    end
  end

  test "#perform_later assumes successful enqueue, but update status later" do
    fake_active_record = FakeActiveRecord.new(false)
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      ErrorTestJob.enqueue_after_transaction_commit = true

      job = ErrorTestJob.perform_later
      assert_instance_of ErrorTestJob, job
      assert_predicate job, :successfully_enqueued?

      fake_active_record.run_after_commit_callbacks
      assert_not_predicate job, :successfully_enqueued?
    end
  end

  test "#perform_later defers enqueue callbacks until after commit" do
    fake_active_record = FakeActiveRecord.new(false)
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      CallbackTestJob.enqueue_after_transaction_commit = true

      job = CallbackTestJob.perform_later
      assert_not_predicate job, :around_enqueue_called
      fake_active_record.run_after_commit_callbacks
      assert_predicate job, :around_enqueue_called
    end
  end

  test "ActiveJob.perform_all_later waits for transactions to complete before enqueuing jobs with `enqueue_after_transaction_commit`" do
    fake_active_record = FakeActiveRecord.new
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      TestJob.enqueue_after_transaction_commit = true

      assert_difference -> { fake_active_record.calls }, +1 do
        ActiveJob.perform_all_later(TestJob.new, TestJob.new)
      end
    end
  end

  test "ActiveJob.perform_all_later handles mixed jobs with and without `enqueue_after_transaction_commit`" do
    fake_active_record = FakeActiveRecord.new(false)
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      TestJob.enqueue_after_transaction_commit = true

      # Mix of jobs with and without enqueue_after_transaction_commit
      immediate_job = ImmediateJob.new
      deferred_job = TestJob.new

      assert_notification("enqueue_all.active_job", jobs: [immediate_job], enqueued_count: 1) do
        ActiveJob.perform_all_later([immediate_job, deferred_job])
      end

      assert_notification("enqueue_all.active_job", jobs: [deferred_job], enqueued_count: 1) do
        fake_active_record.run_after_commit_callbacks
      end
    end
  end

  test "default value is false by default" do
    job_class = Class.new do
      include ActiveJob::Enqueuing
    end

    assert_equal false, job_class.enqueue_after_transaction_commit
  end

  test "can set enqueue_after_transaction_commit without ActiveRecord" do
    original = TestJob.enqueue_after_transaction_commit

    assert_nothing_raised do
      TestJob.enqueue_after_transaction_commit = true
    end
  ensure
    TestJob.enqueue_after_transaction_commit = original
  end

  test "base setting applies to existing subclasses" do
    original = ActiveJob::Base.enqueue_after_transaction_commit
    job_class = Class.new(ActiveJob::Base)

    ActiveJob::Base.enqueue_after_transaction_commit = true

    assert_equal true, job_class.enqueue_after_transaction_commit
  ensure
    ActiveJob::Base.enqueue_after_transaction_commit = original
  end
end
