# frozen_string_literal: true

module ActiveJob
  module EnqueueAfterTransactionCommit # :nodoc:
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      #
      # Defines if enqueueing this job from inside an Active Record transaction
      # automatically defers the enqueue to after the transaction commit.
      #
      # It can be set on a per job basis:
      #  - `:always` forces the job to be deferred.
      #  - `:never` forces the job to be queueed immediately
      #  - `:auto` uses the queue adapter default behavior (recommended).
      class_attribute :enqueue_after_transaction_commit, instance_accessor: false, instance_predicate: false, default: :never

      around_enqueue do |job, block|
        after_transaction = case job.class.enqueue_after_transaction_commit
        when :always
          true
        when :never
          false
        else # :auto
          queue_adapter.respond_to?(:enqueue_after_transaction_commit?) && queue_adapter.enqueue_after_transaction_commit?
        end

        if after_transaction && defined?(::ActiveRecord)
          ActiveRecord.after_all_transactions_commit(&block)
        else
          block.call
        end
      end
    end

    module ClassMethods
      def assign_adapter(adapter_name, queue_adapter)
        super

        unless queue_adapter.respond_to?(:enqueue_after_transaction_commit?)
          class_name = queue_adapter.is_a?(Module) ? queue_adapter.name : queue_adapter.class.name
          ActiveJob.deprecator.warn(<<~MSG)
            #{class_name} doesn't implement the `#enqueue_after_transaction_commit?` method. Assuming false.
          MSG
        end
      end
    end
  end
end
