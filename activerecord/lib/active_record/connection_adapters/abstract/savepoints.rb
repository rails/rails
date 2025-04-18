# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # = Active Record Connection Adapters \Savepoints
    module Savepoints
      def current_savepoint_name
        current_transaction.savepoint_name
      end

      def create_savepoint(name = current_savepoint_name)
        internal_execute("SAVEPOINT #{name}", "TRANSACTION")
      end

      def exec_rollback_to_savepoint(name = current_savepoint_name)
        internal_execute("ROLLBACK TO SAVEPOINT #{name}", "TRANSACTION")
      end

      def release_savepoint(name = current_savepoint_name)
        internal_execute("RELEASE SAVEPOINT #{name}", "TRANSACTION")
      end
    end
  end
end
