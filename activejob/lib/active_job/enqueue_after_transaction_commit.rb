# frozen_string_literal: true

module ActiveJob
  module EnqueueAfterTransactionCommit # :nodoc:
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      #
      # Defines if enqueueing this job from inside an Active Record transaction
      # automatically defers the enqueue to after the transaction commits.
      #
      # It can be set on a per job basis:
      #  - `:always` forces the job to be deferred.
      #  - `:never` forces the job to be queued immediately.
      #  - `:default` lets the queue adapter define the behavior (recommended).
      class_attribute :enqueue_after_transaction_commit, instance_accessor: false, instance_predicate: false, default: :never
    end

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
