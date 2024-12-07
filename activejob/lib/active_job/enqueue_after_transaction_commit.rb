# frozen_string_literal: true

module ActiveJob
  module EnqueueAfterTransactionCommit # :nodoc:
    private
      def raw_enqueue
        enqueue_after_transaction_commit = self.class.enqueue_after_transaction_commit

        after_transaction = case self.class.enqueue_after_transaction_commit
        when :always
          ActiveJob.deprecator.warn(<<~MSG.squish)
            Setting `#{self.class.name}.enqueue_after_transaction_commit = :always` is deprecated and will be removed in Rails 8.1.
            Set to `true` to always enqueue the job after the transaction is committed.
          MSG
          true
        when :never
          ActiveJob.deprecator.warn(<<~MSG.squish)
            Setting `#{self.class.name}.enqueue_after_transaction_commit = :never` is deprecated and will be removed in Rails 8.1.
            Set to `false` to never enqueue the job after the transaction is committed.
          MSG
          false
        when :default
          ActiveJob.deprecator.warn(<<~MSG.squish)
            Setting `#{self.class.name}.enqueue_after_transaction_commit = :default` is deprecated and will be removed in Rails 8.1.
            Set to `false` to never enqueue the job after the transaction is committed.
          MSG
          false
        else
          enqueue_after_transaction_commit
        end

        if after_transaction
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
