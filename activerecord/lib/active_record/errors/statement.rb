module ActiveRecord
  #
  # Superclass for all database execution errors.
  #
  # Wraps the underlying database error as +cause+.
  class StatementInvalid < ActiveRecordError
    def initialize(message = nil)
      super(message || $!.try(:message))
    end
  end

  # Defunct wrapper class kept for compatibility.
  # StatementInvalid wraps the original exception now.
  class WrappedDatabaseException < StatementInvalid
  end

  # Raised when a record cannot be inserted because it would violate a uniqueness constraint.
  class RecordNotUnique < WrappedDatabaseException
  end

  # Raised when a record cannot be inserted or updated because it references a non-existent record.
  class InvalidForeignKey < WrappedDatabaseException
  end

  # Raised when a foreign key constraint cannot be added because the column type does not match the referenced column type.
  class MismatchedForeignKey < StatementInvalid
    def initialize(adapter = nil, message: nil, table: nil, foreign_key: nil, target_table: nil, primary_key: nil)
      @adapter = adapter
      if table
        msg = <<-EOM.strip_heredoc
          Column `#{foreign_key}` on table `#{table}` has a type of `#{column_type(table, foreign_key)}`.
          This does not match column `#{primary_key}` on `#{target_table}`, which has type `#{column_type(target_table, primary_key)}`.
          To resolve this issue, change the type of the `#{foreign_key}` column on `#{table}` to be :integer. (For example `t.integer #{foreign_key}`).
        EOM
      else
        msg = <<-EOM
          There is a mismatch between the foreign key and primary key column types.
          Verify that the foreign key column type and the primary key of the associated table match types.
        EOM
      end
      if message
        msg << "\nOriginal message: #{message}"
      end
      super(msg)
    end

    private
      def column_type(table, column)
        @adapter.columns(table).detect { |c| c.name == column }.sql_type
      end
  end

  # Raised when a record cannot be inserted or updated because it would violate a not null constraint.
  class NotNullViolation < StatementInvalid
  end

  # Raised when a record cannot be inserted or updated because a value too long for a column type.
  class ValueTooLong < StatementInvalid
  end

  # Raised when values that executed are out of range.
  class RangeError < StatementInvalid
  end

  # Raised when number of bind variables in statement given to +:condition+ key
  # (for example, when using {ActiveRecord::Base.find}[rdoc-ref:FinderMethods#find] method)
  # does not match number of expected values supplied.
  #
  # For example, when there are two placeholders with only one value supplied:
  #
  #   Location.where("lat = ? AND lng = ?", 53.7362)
  class PreparedStatementInvalid < StatementInvalid
  end

  # Raised when a given database does not exist.
  class NoDatabaseError < StatementInvalid
  end

  # Raised when Postgres returns 'cached plan must not change result type' and
  # we cannot retry gracefully (e.g. inside a transaction)
  class PreparedStatementCacheExpired < StatementInvalid
  end

  # TransactionRollbackError will be raised when a transaction is rolled
  # back by the database due to a serialization failure or a deadlock.
  #
  # See the following:
  #
  # * http://www.postgresql.org/docs/current/static/transaction-iso.html
  # * https://dev.mysql.com/doc/refman/5.7/en/error-messages-server.html#error_er_lock_deadlock
  class TransactionRollbackError < StatementInvalid
  end

  # SerializationFailure will be raised when a transaction is rolled
  # back by the database due to a serialization failure.
  class SerializationFailure < TransactionRollbackError
  end

  # Deadlocked will be raised when a transaction is rolled
  # back by the database when a deadlock is encountered.
  class Deadlocked < TransactionRollbackError
  end
end
