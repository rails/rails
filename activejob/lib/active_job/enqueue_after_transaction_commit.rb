# frozen_string_literal: true

module ActiveJob
  class << self
    # Ensures perform_all_later respects each job's enqueue_after_transaction_commit configuration.
    # Jobs with enqueue_after_transaction_commit set to true are deferred and enqueued only after the transaction commits;
    # other jobs are enqueued immediately. This ensures enqueuing timing matches the per-job setting.
    alias _perform_all_later_skip_transaction perform_all_later
    def perform_all_later(*jobs)
      jobs.flatten!
      deferred_jobs, immediate_jobs = jobs.partition { |job| job.class.enqueue_after_transaction_commit }
      _perform_all_later_skip_transaction(immediate_jobs) if immediate_jobs.any?
      ActiveRecord.after_all_transactions_commit { _perform_all_later_skip_transaction(deferred_jobs) } if deferred_jobs.any?
      nil
    end
  end

  module EnqueueAfterTransactionCommit # :nodoc:
    private
      def raw_enqueue
        if self.class.enqueue_after_transaction_commit
          self.successfully_enqueued = true
          ActiveRecord.after_all_transactions_commit do
            self.successfully_enqueued = false
            super
          end
          self
        else
          super
        end
      end
  end
end
