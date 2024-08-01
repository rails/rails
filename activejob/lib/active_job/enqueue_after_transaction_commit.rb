# frozen_string_literal: true

module ActiveJob
  module EnqueueAfterTransactionCommit # :nodoc:
    private
      def raw_enqueue
        after_transaction = case self.class.enqueue_after_transaction_commit
        when :always
          true
        when :never
          false
        else # :default
          queue_adapter.enqueue_after_transaction_commit?
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
