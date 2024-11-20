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

  class EnqueueAfterCommitJob < ActiveJob::Base
    self.enqueue_after_transaction_commit = true

    def perform
      # noop
    end
  end

  class ErrorEnqueueAfterCommitJob < EnqueueErrorJob
    class EnqueueErrorAdapter
      def enqueue(...)
        raise ActiveJob::EnqueueError, "There was an error enqueuing the job"
      end

      def enqueue_at(...)
        raise ActiveJob::EnqueueError, "There was an error enqueuing the job"
      end
    end

    self.queue_adapter = EnqueueErrorAdapter.new
    self.enqueue_after_transaction_commit = true

    def perform
      # noop
    end
  end

  test "#perform_later wait for transactions to complete before enqueuing the job" do
    fake_active_record = FakeActiveRecord.new
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      assert_difference -> { fake_active_record.calls }, +1 do
        EnqueueAfterCommitJob.perform_later
      end
    end
  end

  test "#perform_later returns the Job instance even if it's delayed by `after_all_transactions_commit`" do
    fake_active_record = FakeActiveRecord.new(false)
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      job = EnqueueAfterCommitJob.perform_later
      assert_instance_of EnqueueAfterCommitJob, job
      assert_predicate job, :successfully_enqueued?
    end
  end

  test "#perform_later yields the enqueued Job instance even if it's delayed by `after_all_transactions_commit`" do
    fake_active_record = FakeActiveRecord.new(false)
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      called = false
      job = EnqueueAfterCommitJob.perform_later do |yielded_job|
        called = true
        assert_instance_of EnqueueAfterCommitJob, yielded_job
      end
      assert called, "#perform_later yielded the job"
      assert_instance_of EnqueueAfterCommitJob, job
      assert_predicate job, :successfully_enqueued?
    end
  end

  test "#perform_later assumes successful enqueue, but update status later" do
    fake_active_record = FakeActiveRecord.new(false)
    stub_const(Object, :ActiveRecord, fake_active_record, exists: false) do
      job = ErrorEnqueueAfterCommitJob.perform_later
      assert_instance_of ErrorEnqueueAfterCommitJob, job
      assert_predicate job, :successfully_enqueued?

      fake_active_record.run_after_commit_callbacks
      assert_not_predicate job, :successfully_enqueued?
    end
  end
end
