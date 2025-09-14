# frozen_string_literal: true

require "active_support/deprecation"

module ActiveRecord
  include ActiveSupport::Deprecation::DeprecatedConstantAccessor

  # = Active Record Errors
  #
  # Generic Active Record exception class.
  class ActiveRecordError < StandardError
  end

  # Raised when the single-table inheritance mechanism fails to locate the subclass
  # (for example due to improper usage of column that
  # {ActiveRecord::Base.inheritance_column}[rdoc-ref:ModelSchema.inheritance_column]
  # points to).
  class SubclassNotFound < ActiveRecordError
  end

  # Raised when an object assigned to an association has an incorrect type.
  #
  #   class Ticket < ActiveRecord::Base
  #     has_many :patches
  #   end
  #
  #   class Patch < ActiveRecord::Base
  #     belongs_to :ticket
  #   end
  #
  #   # Comments are not patches, this assignment raises AssociationTypeMismatch.
  #   @ticket.patches << Comment.new(content: "Please attach tests to your patch.")
  class AssociationTypeMismatch < ActiveRecordError
  end

  # Raised when unserialized object's type mismatches one specified for serializable field.
  class SerializationTypeMismatch < ActiveRecordError
  end

  # Raised when adapter not specified on connection (or configuration file
  # +config/database.yml+ misses adapter field).
  class AdapterNotSpecified < ActiveRecordError
  end

  # Raised when a model makes a query but it has not specified an associated table.
  class TableNotSpecified < ActiveRecordError
  end

  # Raised when Active Record cannot find database adapter specified in
  # +config/database.yml+ or programmatically.
  class AdapterNotFound < ActiveRecordError
  end

  # Superclass for all errors raised from an Active Record adapter.
  class AdapterError < ActiveRecordError
    def initialize(message = nil, connection_pool: nil)
      @connection_pool = connection_pool
      super(message)
    end

    attr_reader :connection_pool
  end

  # Raised when connection to the database could not been established (for example when
  # {ActiveRecord::Base.lease_connection=}[rdoc-ref:ConnectionHandling#lease_connection]
  # is given a +nil+ object).
  class ConnectionNotEstablished < AdapterError
    def initialize(message = nil, connection_pool: nil)
      super(message, connection_pool: connection_pool)
    end

    def set_pool(connection_pool)
      unless @connection_pool
        @connection_pool = connection_pool
      end

      self
    end
  end

  # Raised when a connection could not be obtained within the connection
  # acquisition timeout period: because max connections in pool
  # are in use.
  class ConnectionTimeoutError < ConnectionNotEstablished
  end

  # Raised when a database connection pool is requested but
  # has not been defined.
  class ConnectionNotDefined < ConnectionNotEstablished
    def initialize(message = nil, connection_name: nil, role: nil, shard: nil)
      super(message)
      @connection_name = connection_name
      @role = role
      @shard = shard
    end

    attr_reader :connection_name, :role, :shard
  end

  # Raised when connection to the database could not been established because it was not
  # able to connect to the host or when the authorization failed.
  class DatabaseConnectionError < ConnectionNotEstablished
    def initialize(message = nil)
      super(message || "Database connection error")
    end

    class << self
      def hostname_error(hostname)
        DatabaseConnectionError.new(<<~MSG)
          There is an issue connecting with your hostname: #{hostname}.\n
          Please check your database configuration and ensure there is a valid connection to your database.
        MSG
      end

      def username_error(username)
        DatabaseConnectionError.new(<<~MSG)
          There is an issue connecting to your database with your username/password, username: #{username}.\n
          Please check your database configuration to ensure the username/password are valid.
        MSG
      end
    end
  end

  # Raised when a pool was unable to get ahold of all its connections
  # to perform a "group" action such as
  # {ActiveRecord::Base.connection_pool.disconnect!}[rdoc-ref:ConnectionAdapters::ConnectionPool#disconnect!]
  # or {ActiveRecord::Base.connection_handler.clear_reloadable_connections!}[rdoc-ref:ConnectionAdapters::ConnectionHandler#clear_reloadable_connections!].
  class ExclusiveConnectionTimeoutError < ConnectionTimeoutError
  end

  # Raised when a write to the database is attempted on a read only connection.
  class ReadOnlyError < ActiveRecordError
  end

  # Raised when Active Record cannot find a record by given id or set of ids.
  class RecordNotFound < ActiveRecordError
    attr_reader :model, :primary_key, :id

    def initialize(message = nil, model = nil, primary_key = nil, id = nil)
      @primary_key = primary_key
      @model = model
      @id = id

      super(message)
    end
  end

  # Raised by {ActiveRecord::Base#save!}[rdoc-ref:Persistence#save!] and
  # {ActiveRecord::Base.update_attribute!}[rdoc-ref:Persistence#update_attribute!]
  # methods when a record failed to validate or cannot be saved due to any of the
  # <tt>before_*</tt> callbacks throwing +:abort+. See
  # ActiveRecord::Callbacks for further details.
  #
  #   class Product < ActiveRecord::Base
  #     before_save do
  #       throw :abort if price < 0
  #     end
  #   end
  #
  #   Product.create! # => raises an ActiveRecord::RecordNotSaved
  class RecordNotSaved < ActiveRecordError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Raised by {ActiveRecord::Base#destroy!}[rdoc-ref:Persistence#destroy!]
  # when a record cannot be destroyed due to any of the
  # <tt>before_destroy</tt> callbacks throwing +:abort+. See
  # ActiveRecord::Callbacks for further details.
  #
  #   class User < ActiveRecord::Base
  #     before_destroy do
  #       throw :abort if still_active?
  #     end
  #   end
  #
  #   User.first.destroy! # => raises an ActiveRecord::RecordNotDestroyed
  class RecordNotDestroyed < ActiveRecordError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Raised when Active Record finds multiple records but only expected one.
  class SoleRecordExceeded < ActiveRecordError
    attr_reader :record

    def initialize(record = nil)
      @record = record
      super "Wanted only one #{record&.name || "record"}"
    end
  end

  # Superclass for all database execution errors.
  #
  # Wraps the underlying database error as +cause+.
  class StatementInvalid < AdapterError
    def initialize(message = nil, sql: nil, binds: nil, connection_pool: nil)
      super(message || $!&.message, connection_pool: connection_pool)
      @sql = sql
      @binds = binds
    end

    attr_reader :sql, :binds

    def set_query(sql, binds)
      unless @sql
        @sql = sql
        @binds = binds
      end

      self
    end
  end

  # Defunct wrapper class kept for compatibility.
  # StatementInvalid wraps the original exception now.
  class WrappedDatabaseException < StatementInvalid
  end

  # Raised when a record cannot be inserted or updated because it would violate a uniqueness constraint.
  class RecordNotUnique < WrappedDatabaseException
  end

  # Raised when a record cannot be inserted or updated because it references a non-existent record,
  # or when a record cannot be deleted because a parent record references it.
  class InvalidForeignKey < WrappedDatabaseException
  end

  # Raised when a foreign key constraint cannot be added because the column type does not match the referenced column type.
  class MismatchedForeignKey < StatementInvalid
    def initialize(
      message: nil,
      sql: nil,
      binds: nil,
      table: nil,
      foreign_key: nil,
      target_table: nil,
      primary_key: nil,
      primary_key_column: nil,
      query_parser: nil,
      connection_pool: nil
    )
      @original_message = message
      @query_parser = query_parser

      if table
        type = primary_key_column.bigint? ? :bigint : primary_key_column.type
        msg = <<~EOM.squish
          Column `#{foreign_key}` on table `#{table}` does not match column `#{primary_key}` on `#{target_table}`,
          which has type `#{primary_key_column.sql_type}`.
          To resolve this issue, change the type of the `#{foreign_key}` column on `#{table}` to be :#{type}.
          (For example `t.#{type} :#{foreign_key}`).
        EOM
      else
        msg = <<~EOM.squish
          There is a mismatch between the foreign key and primary key column types.
          Verify that the foreign key column type and the primary key of the associated table match types.
        EOM
      end
      if message
        msg << "\nOriginal message: #{message}"
      end

      super(msg, sql: sql, binds: binds, connection_pool: connection_pool)
    end

    def set_query(sql, binds)
      if @query_parser && !@sql
        self.class.new(
          message: @original_message,
          sql: sql,
          binds: binds,
          connection_pool: @connection_pool,
          **@query_parser.call(sql)
        ).tap do |exception|
          exception.set_backtrace backtrace
        end
      else
        super
      end
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

  # Raised when a statement produces an SQL warning.
  class SQLWarning < AdapterError
    attr_reader :code, :level
    attr_accessor :sql

    def initialize(message = nil, code = nil, level = nil, sql = nil, connection_pool = nil)
      super(message, connection_pool: connection_pool)
      @code = code
      @level = level
      @sql = sql
    end
  end

  # Raised when the number of placeholders in an SQL fragment passed to
  # {ActiveRecord::Base.where}[rdoc-ref:QueryMethods#where]
  # does not match the number of values supplied.
  #
  # For example, when there are two placeholders with only one value supplied:
  #
  #   Location.where("lat = ? AND lng = ?", 53.7362)
  class PreparedStatementInvalid < ActiveRecordError
  end

  # Raised when a given database does not exist.
  class NoDatabaseError < StatementInvalid
    include ActiveSupport::ActionableError

    action "Create database" do
      ActiveRecord::Tasks::DatabaseTasks.create_current
    end

    def initialize(message = nil, connection_pool: nil)
      super(message || "Database not found", connection_pool: connection_pool)
    end

    class << self
      def db_error(db_name)
        NoDatabaseError.new(<<~MSG)
          We could not find your database: #{db_name}. Available database configurations can be found in config/database.yml.

          To resolve this error:

          - Did you not create the database, or did you delete it? To create the database, run:

              bin/rails db:create

          - Has the database name changed? Verify that config/database.yml contains the correct database name.
        MSG
      end
    end
  end

  # Raised when creating a database if it exists.
  class DatabaseAlreadyExists < StatementInvalid
  end

  # Raised when PostgreSQL returns 'cached plan must not change result type' and
  # we cannot retry gracefully (e.g. inside a transaction)
  class PreparedStatementCacheExpired < StatementInvalid
  end

  # Raised on attempt to save stale record. Record is stale when it's being saved in another query after
  # instantiation, for example, when two users edit the same wiki page and one starts editing and saves
  # the page before the other.
  #
  # Read more about optimistic locking in ActiveRecord::Locking module
  # documentation.
  class StaleObjectError < ActiveRecordError
    attr_reader :record, :attempted_action

    def initialize(record = nil, attempted_action = nil)
      if record && attempted_action
        @record = record
        @attempted_action = attempted_action
        super("Attempted to #{attempted_action} a stale object: #{record.class.name}.")
      else
        super("Stale object error.")
      end
    end
  end

  # Raised when association is being configured improperly or user tries to use
  # offset and limit together with
  # {ActiveRecord::Base.has_many}[rdoc-ref:Associations::ClassMethods#has_many] or
  # {ActiveRecord::Base.has_and_belongs_to_many}[rdoc-ref:Associations::ClassMethods#has_and_belongs_to_many]
  # associations.
  class ConfigurationError < ActiveRecordError
  end

  # Raised on attempt to update record that is instantiated as read only.
  class ReadOnlyRecord < ActiveRecordError
  end

  # Raised on attempt to lazily load records that are marked as strict loading.
  #
  # You can resolve this error by eager loading marked records before accessing
  # them. The
  # {Eager Loading Associations}[https://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations]
  # guide covers solutions, such as using
  # {ActiveRecord::Base.includes}[rdoc-ref:QueryMethods#includes].
  class StrictLoadingViolationError < ActiveRecordError
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
  #           raise ActiveRecord::Rollback
  #         end
  #       end
  #       # ActiveRecord::Rollback is the only exception that won't be passed on
  #       # by ActiveRecord::Base.transaction, so this line will still be reached
  #       # even on Friday.
  #       redirect_to root_url
  #     end
  #   end
  class Rollback < ActiveRecordError
  end

  # Raised when attribute has a name reserved by Active Record (when attribute
  # has name of one of Active Record instance methods).
  class DangerousAttributeError < ActiveRecordError
  end

  # Raised when unknown attributes are supplied via mass assignment.
  UnknownAttributeError = ActiveModel::UnknownAttributeError

  # Raised when an error occurred while doing a mass assignment to an attribute through the
  # {ActiveRecord::Base#attributes=}[rdoc-ref:ActiveModel::AttributeAssignment#attributes=] method.
  # The exception has an +attribute+ property that is the name of the offending attribute.
  class AttributeAssignmentError < ActiveRecordError
    attr_reader :exception, :attribute

    def initialize(message = nil, exception = nil, attribute = nil)
      super(message)
      @exception = exception
      @attribute = attribute
    end
  end

  # Raised when there are multiple errors while doing a mass assignment through the
  # {ActiveRecord::Base#attributes=}[rdoc-ref:ActiveModel::AttributeAssignment#attributes=]
  # method. The exception has an +errors+ property that contains an array of AttributeAssignmentError
  # objects, each corresponding to the error while assigning to an attribute.
  class MultiparameterAssignmentErrors < ActiveRecordError
    attr_reader :errors

    def initialize(errors = nil)
      @errors = errors
    end
  end

  # Raised when a primary key is needed, but not specified in the schema or model.
  class UnknownPrimaryKey < ActiveRecordError
    attr_reader :model

    def initialize(model = nil, description = nil)
      if model
        message = "Unknown primary key for table #{model.table_name} in model #{model}."
        message += "\n#{description}" if description
        @model = model
        super(message)
      else
        super("Unknown primary key.")
      end
    end
  end

  # Raised when a relation cannot be mutated because it's already loaded.
  #
  #   class Task < ActiveRecord::Base
  #   end
  #
  #   relation = Task.all
  #   relation.loaded? # => true
  #
  #   # Methods which try to mutate a loaded relation fail.
  #   relation.where!(title: 'TODO')  # => ActiveRecord::UnmodifiableRelation
  #   relation.limit!(5)              # => ActiveRecord::UnmodifiableRelation
  class UnmodifiableRelation < ActiveRecordError
  end

  # TransactionIsolationError will be raised under the following conditions:
  #
  # * The adapter does not support setting the isolation level
  # * You are joining an existing open transaction
  # * You are creating a nested (savepoint) transaction
  #
  # The mysql2, trilogy, and postgresql adapters support setting the transaction isolation level.
  class TransactionIsolationError < ActiveRecordError
  end

  # TransactionRollbackError will be raised when a transaction is rolled
  # back by the database due to a serialization failure or a deadlock.
  #
  # These exceptions should not be generally rescued in nested transaction
  # blocks, because they have side-effects in the actual enclosing transaction
  # and internal Active Record state. They can be rescued if you are above the
  # root transaction block, though.
  #
  # In that case, beware of transactional tests, however, because they run test
  # cases in their own umbrella transaction. If you absolutely need to handle
  # these exceptions in tests please consider disabling transactional tests in
  # the affected test class (<tt>self.use_transactional_tests = false</tt>).
  #
  # Due to the aforementioned side-effects, this exception should not be raised
  # manually by users.
  #
  # See the following:
  #
  # * https://www.postgresql.org/docs/current/static/transaction-iso.html
  # * https://dev.mysql.com/doc/mysql-errors/en/server-error-reference.html#error_er_lock_deadlock
  class TransactionRollbackError < StatementInvalid
  end

  # AsynchronousQueryInsideTransactionError will be raised when attempting
  # to perform an asynchronous query from inside a transaction
  class AsynchronousQueryInsideTransactionError < ActiveRecordError
  end

  # SerializationFailure will be raised when a transaction is rolled
  # back by the database due to a serialization failure.
  #
  # This is a subclass of TransactionRollbackError, please make sure to check
  # its documentation to be aware of its caveats.
  class SerializationFailure < TransactionRollbackError
  end

  # Deadlocked will be raised when a transaction is rolled
  # back by the database when a deadlock is encountered.
  #
  # This is a subclass of TransactionRollbackError, please make sure to check
  # its documentation to be aware of its caveats.
  class Deadlocked < TransactionRollbackError
  end

  # IrreversibleOrderError is raised when a relation's order is too complex for
  # +reverse_order+ to automatically reverse.
  class IrreversibleOrderError < ActiveRecordError
  end

  # Superclass for errors that have been aborted (either by client or server).
  class QueryAborted < StatementInvalid
  end

  # LockWaitTimeout will be raised when lock wait timeout exceeded.
  class LockWaitTimeout < StatementInvalid
  end

  # StatementTimeout will be raised when statement timeout exceeded.
  class StatementTimeout < QueryAborted
  end

  # QueryCanceled will be raised when canceling statement due to user request.
  class QueryCanceled < QueryAborted
  end

  # AdapterTimeout will be raised when database clients times out while waiting from the server.
  class AdapterTimeout < QueryAborted
  end

  # ConnectionFailed will be raised when the network connection to the
  # database fails while sending a query or waiting for its result.
  class ConnectionFailed < QueryAborted
  end

  # UnknownAttributeReference is raised when an unknown and potentially unsafe
  # value is passed to a query method. For example, passing a non column name
  # value to a relation's #order method might cause this exception.
  #
  # When working around this exception, caution should be taken to avoid SQL
  # injection vulnerabilities when passing user-provided values to query
  # methods. Known-safe values can be passed to query methods by wrapping them
  # in Arel.sql.
  #
  # For example, the following code would raise this exception:
  #
  #   Post.order("REPLACE(title, 'misc', 'zzzz') asc").pluck(:id)
  #
  # The desired result can be accomplished by wrapping the known-safe string
  # in Arel.sql:
  #
  #   Post.order(Arel.sql("REPLACE(title, 'misc', 'zzzz') asc")).pluck(:id)
  #
  # Again, such a workaround should *not* be used when passing user-provided
  # values, such as request parameters or model attributes to query methods.
  class UnknownAttributeReference < ActiveRecordError
  end

  # DatabaseVersionError will be raised when the database version is not supported, or when
  # the database version cannot be determined.
  class DatabaseVersionError < ActiveRecordError
  end
end

require "active_record/associations/errors"
