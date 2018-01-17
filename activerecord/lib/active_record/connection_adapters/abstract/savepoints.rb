# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Savepoints
      def current_savepoint_name
        current_transaction.savepoint_name
      end

      def create_savepoint(name = current_savepoint_name)
        execute("SAVEPOINT #{name}")
      end

      def exec_rollback_to_savepoint(name = current_savepoint_name)
        execute("ROLLBACK TO SAVEPOINT #{name}")
      end

      def release_savepoint(name = current_savepoint_name)
        execute("RELEASE SAVEPOINT #{name}")
      end
    end
  end
end
