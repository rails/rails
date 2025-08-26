# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # = Active Record Connection Adapters \Savepoints
    module Savepoints
      def current_savepoint_name
        current_transaction.savepoint_name
      end

      def create_savepoint(name = current_savepoint_name)
        query_command("SAVEPOINT #{name}", "TRANSACTION")
      end

      def exec_rollback_to_savepoint(name = current_savepoint_name)
        query_command("ROLLBACK TO SAVEPOINT #{name}", "TRANSACTION")
      end

      def release_savepoint(name = current_savepoint_name)
        query_command("RELEASE SAVEPOINT #{name}", "TRANSACTION")
      end
    end
  end
end
