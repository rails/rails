# frozen_string_literal: true

module ActiveStorage::InMemoryBackend
  class Transaction
    class << self
      def current
        ActiveSupport::IsolatedExecutionState[:active_storage_memory_transaction]
      end

      def open
        return yield if current

        transaction = new
        ActiveSupport::IsolatedExecutionState[:active_storage_memory_transaction] = transaction
        begin
          result = yield
        rescue Exception
          ActiveSupport::IsolatedExecutionState.delete(:active_storage_memory_transaction)
          transaction.rollback
          raise
        else
          ActiveSupport::IsolatedExecutionState.delete(:active_storage_memory_transaction)
          transaction.commit
          result
        ensure
          ActiveSupport::IsolatedExecutionState.delete(:active_storage_memory_transaction)
        end
      end

      def enlist(record)
        current&.enlist(record)
      end

      def committed(record)
        if current
          current.committed(record)
        elsif record.class.respond_to?(:_commit_callbacks, true)
          record.run_callbacks(:commit) { true }
        end
      end
    end

    def initialize
      @stores = {}.compare_by_identity
      @records = {}.compare_by_identity
      @committed = {}.compare_by_identity
    end

    def enlist(record)
      @stores[record.class] ||= record.class.store.each_pair.to_h.deep_dup
      @records[record] = record.instance_variable_get(:@persisted) unless @records.key?(record)
    end

    def committed(record)
      @committed[record] = true
    end

    def commit
      @committed.each_key do |record|
        record.run_callbacks(:commit) { true } if record.class.respond_to?(:_commit_callbacks, true)
      end
    end

    def rollback
      @stores.each do |model, attributes|
        model.store.clear
        attributes.each { |id, values| model.store[id] = values.deep_dup }
      end
      @records.each do |record, persisted|
        record.instance_variable_set(:@persisted, persisted)
      end
      @records.each_key do |record|
        record.run_callbacks(:rollback) { true } if record.class.respond_to?(:_rollback_callbacks, true)
      end
    end
  end
end
