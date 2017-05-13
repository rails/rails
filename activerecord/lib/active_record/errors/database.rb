module ActiveRecord
  # Superclass for all ActiveRecord database errors.
  # Subclasses of this error class are:
  # - AdapterError
  # - ConnectionError
  # - TransactionError
  class DatabaseError < ActiveRecordError
  end

  #
  # Superclass for all adapter errors.
  #
  class AdapterError < DatabaseError
  end

  # Raised when adapter not specified on connection (or configuration file
  # +config/database.yml+ misses adapter field).
  class AdapterNotSpecified < AdapterError
  end

  # Raised when Active Record cannot find database adapter specified in
  # +config/database.yml+ or programmatically.
  class AdapterNotFound < AdapterError
  end

  class AdapterTypeInconsistentWithByteLength < AdapterError # :nodoc:
  end

  # Raised when a given database does not exist.
  class DatabaseVersionNotSupported < AdapterError
  end

  class NoSuchColumn < AdapterError # :nodoc:
    def initialize(table_name = nil, column_name = nil)
      super("No such column: #{table_name}.#{column_name}")
    end
  end

  #
  # Superclass for all connection errors.
  #
  class ConnectionError < DatabaseError
  end

  class CannotLeaseConnection < ConnectionError # :nodoc:
  end

  class CannotExpireConnection < ConnectionError  # :nodoc:
  end

  # Raised when connection to the database could not been established (for example when
  # {ActiveRecord::Base.connection=}[rdoc-ref:ConnectionHandling#connection]
  # is given a nil object).
  class ConnectionNotEstablished < ConnectionError
  end

  # Raised when a connection could not be obtained within the connection
  # acquisition timeout period: because max connections in pool
  # are in use.
  class ConnectionTimeoutError < ConnectionNotEstablished
  end

  # Raised when a pool was unable to get ahold of all its connections
  # to perform a "group" action such as
  # {ActiveRecord::Base.connection_pool.disconnect!}[rdoc-ref:ConnectionAdapters::ConnectionPool#disconnect!]
  # or {ActiveRecord::Base.clear_reloadable_connections!}[rdoc-ref:ConnectionAdapters::ConnectionHandler#clear_reloadable_connections!].
  class ExclusiveConnectionTimeoutError < ConnectionTimeoutError
  end

  #
  # Superclass for all transaction errors.
  #
  class TransactionError < DatabaseError
  end

  # {ActiveRecord::Base.transaction}[rdoc-ref:Transactions::ClassMethods#transaction]
  # uses this exception to distinguish a deliberate rollback from other exceptional situations.
  # Normally, raising an exception will cause the
  # {.transaction}[rdoc-ref:Transactions::ClassMethods#transaction] method to rollback
  # the database transaction *and* pass on the exception. But if you raise an
  # ActiveRecord::Rollback exception, then the database transaction will be rolled back,
  # without passing on the exception.
  #
  # For example, you could do this in your controller to rollback a transaction:
  #
  #   class BooksController < ActionController::Base
  #     def create
  #       Book.transaction do
  #         book = Book.new(params[:book])
  #         book.save!
  #         if today_is_friday?
  #           # The system must fail on Friday so that our support department
  #           # won't be out of job. We silently rollback this transaction
  #           # without telling the user.
  #           raise ActiveRecord::Rollback, "Call tech support!"
  #         end
  #       end
  #       # ActiveRecord::Rollback is the only exception that won't be passed on
  #       # by ActiveRecord::Base.transaction, so this line will still be reached
  #       # even on Friday.
  #       redirect_to root_url
  #     end
  #   end
  class Rollback < TransactionError
  end

  # TransactionIsolationError will be raised under the following conditions:
  #
  # * The adapter does not support setting the isolation level
  # * You are joining an existing open transaction
  # * You are creating a nested (savepoint) transaction
  #
  # The mysql2 and postgresql adapters support setting the transaction isolation level.
  class TransactionIsolationError < TransactionError
  end

  # TransactionSerializationError will be raised when a transaction is rolled
  # back by the database due to a serialization failure or a deadlock.
  #
  # See the following:
  #
  # * http://www.postgresql.org/docs/current/static/transaction-iso.html
  # * https://dev.mysql.com/doc/refman/5.7/en/error-messages-server.html#error_er_lock_deadlock
  class TransactionSerializationError < TransactionError
  end
end
