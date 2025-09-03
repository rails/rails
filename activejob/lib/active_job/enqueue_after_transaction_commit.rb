# frozen_string_literal: true

module ActiveJob
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
