require "active_record/type"
require "active_record/connection_adapters/determine_if_preparable_visitor"
require "active_record/connection_adapters/schema_cache"
require "active_record/connection_adapters/sql_type_metadata"
require "active_record/connection_adapters/abstract/schema_dumper"
require "active_record/connection_adapters/abstract/schema_creation"
require "arel/collectors/bind"
require "arel/collectors/sql_string"

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    extend ActiveSupport::Autoload

    autoload :Column
    autoload :ConnectionSpecification

    autoload_at "active_record/connection_adapters/abstract/schema_definitions" do
      autoload :IndexDefinition
      autoload :ColumnDefinition
      autoload :ChangeColumnDefinition
      autoload :ForeignKeyDefinition
      autoload :TableDefinition
      autoload :Table
      autoload :AlterTable
      autoload :ReferenceDefinition
    end

    autoload_at "active_record/connection_adapters/abstract/connection_pool" do
      autoload :ConnectionHandler
    end

    autoload_under "abstract" do
      autoload :SchemaStatements
      autoload :DatabaseStatements
      autoload :DatabaseLimits
      autoload :Quoting
      autoload :ConnectionPool
      autoload :QueryCache
      autoload :Savepoints
    end

    autoload_at "active_record/connection_adapters/abstract/transaction" do
      autoload :TransactionManager
      autoload :NullTransaction
      autoload :RealTransaction
      autoload :SavepointTransaction
      autoload :TransactionState
    end

    # Active Record supports multiple database systems. AbstractAdapter and
    # related classes form the abstraction layer which makes this possible.
    # An AbstractAdapter represents a connection to a database, and provides an
    # abstract interface for database-specific functionality such as establishing
    # a connection, escaping values, building the right SQL fragments for +:offset+
    # and +:limit+ options, etc.
    #
    # All the concrete database adapters follow the interface laid down in this class.
    # {ActiveRecord::Base.connection}[rdoc-ref:ConnectionHandling#connection] returns an AbstractAdapter object, which
    # you can use.
    #
    # Most of the methods in the adapter are useful during migrations. Most
    # notably, the instance methods provided by SchemaStatements are very useful.
    class AbstractAdapter
      ADAPTER_NAME = "Abstract".freeze
      include Quoting, DatabaseStatements, SchemaStatements
      include DatabaseLimits
      include QueryCache
      include ActiveSupport::Callbacks
      include ColumnDumper
      include Savepoints

      SIMPLE_INT = /\A\d+\z/

      define_callbacks :checkout, :checkin

      attr_accessor :visitor, :pool
      attr_reader :schema_cache, :owner, :logger
      alias :in_use? :owner

      def self.type_cast_config_to_integer(config)
        if config =~ SIMPLE_INT
          config.to_i
        else
          config
        end
      end

      def self.type_cast_config_to_boolean(config)
        if config == "false"
          false
        else
          config
        end
      end

      attr_reader :prepared_statements

      def initialize(connection, logger = nil, config = {}) # :nodoc:
        super()

        @connection          = connection
        @owner               = nil
        @instrumenter        = ActiveSupport::Notifications.instrumenter
        @logger              = logger
        @config              = config
        @pool                = nil
        @schema_cache        = SchemaCache.new self
        @quoted_column_names, @quoted_table_names = {}, {}
        @visitor             = arel_visitor

        if self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements) { true })
          @prepared_statements = true
          @visitor.extend(DetermineIfPreparableVisitor)
        else
          @prepared_statements = false
        end
      end

      class Version
        include Comparable

        def initialize(version_string)
          @version = version_string.split(".").map(&:to_i)
        end

        def <=>(version_string)
          @version <=> version_string.split(".").map(&:to_i)
        end
      end

      class BindCollector < Arel::Collectors::Bind
        def compile(bvs, conn)
          casted_binds = bvs.map(&:value_for_database)
          super(casted_binds.map { |value| conn.quote(value) })
        end
      end

      class SQLString < Arel::Collectors::SQLString
        def compile(bvs, conn)
          super(bvs)
        end
      end

      def collector
        if prepared_statements
          SQLString.new
        else
          BindCollector.new
        end
      end

      def arel_visitor # :nodoc:
        Arel::Visitors::ToSql.new(self)
      end

      def valid_type?(type)
        false
      end

      def schema_creation
        SchemaCreation.new self
      end

      # this method must only be called while holding connection pool's mutex
      def lease
        if in_use?
          msg = "Cannot lease connection, "
          if @owner == Thread.current
            msg << "it is already leased by the current thread."
          else
            msg << "it is already in use by a different thread: #{@owner}. " <<
                   "Current thread: #{Thread.current}."
          end
          raise ActiveRecordError, msg
        end

        @owner = Thread.current
      end

      def schema_cache=(cache)
        cache.connection = self
        @schema_cache = cache
      end

      # this method must only be called while holding connection pool's mutex
      def expire
        if in_use?
          if @owner != Thread.current
            raise ActiveRecordError, "Cannot expire connection, " <<
              "it is owned by a different thread: #{@owner}. " <<
              "Current thread: #{Thread.current}."
          end

          @owner = nil
        else
          raise ActiveRecordError, "Cannot expire connection, it is not currently leased."
        end
      end

      # this method must only be called while holding connection pool's mutex (and a desire for segfaults)
      def steal! # :nodoc:
        if in_use?
          if @owner != Thread.current
            pool.send :remove_connection_from_thread_cache, self, @owner

            @owner = Thread.current
          end
        else
          raise ActiveRecordError, "Cannot steal connection, it is not currently leased."
        end
      end

      def unprepared_statement
        old_prepared_statements, @prepared_statements = @prepared_statements, false
        yield
      ensure
        @prepared_statements = old_prepared_statements
      end

      # Returns the human-readable name of the adapter. Use mixed case - one
      # can always use downcase if needed.
      def adapter_name
        self.class::ADAPTER_NAME
      end

      # Does this adapter support migrations?
      def supports_migrations?
        false
      end

      # Can this adapter determine the primary key for tables not attached
      # to an Active Record class, such as join tables?
      def supports_primary_key?
        false
      end

      # Does this adapter support DDL rollbacks in transactions? That is, would
      # CREATE TABLE or ALTER TABLE get rolled back by a transaction?
      def supports_ddl_transactions?
        false
      end

      def supports_bulk_alter?
        false
      end

      # Does this adapter support savepoints?
      def supports_savepoints?
        false
      end

      # Does this adapter support application-enforced advisory locking?
      def supports_advisory_locks?
        false
      end

      # Should primary key values be selected from their corresponding
      # sequence before the insert statement? If true, next_sequence_value
      # is called before each insert to set the record's primary key.
      def prefetch_primary_key?(table_name = nil)
        false
      end

      # Does this adapter support index sort order?
      def supports_index_sort_order?
        false
      end

      # Does this adapter support partial indices?
      def supports_partial_index?
        false
      end

      # Does this adapter support expression indices?
      def supports_expression_index?
        false
      end

      # Does this adapter support explain?
      def supports_explain?
        false
      end

      # Does this adapter support setting the isolation level for a transaction?
      def supports_transaction_isolation?
        false
      end

      # Does this adapter support database extensions?
      def supports_extensions?
        false
      end

      # Does this adapter support creating indexes in the same statement as
      # creating the table?
      def supports_indexes_in_create?
        false
      end

      # Does this adapter support creating foreign key constraints?
      def supports_foreign_keys?
        false
      end

      # Does this adapter support views?
      def supports_views?
        false
      end

      # Does this adapter support datetime with precision?
      def supports_datetime_with_precision?
        false
      end

      # Does this adapter support json data type?
      def supports_json?
        false
      end

      # Does this adapter support metadata comments on database objects (tables, columns, indexes)?
      def supports_comments?
        false
      end

      # Can comments for tables, columns, and indexes be specified in create/alter table statements?
      def supports_comments_in_create?
        false
      end

      # Does this adapter support multi-value insert?
      def supports_multi_insert?
        true
      end

      # This is meant to be implemented by the adapters that support extensions
      def disable_extension(name)
      end

      # This is meant to be implemented by the adapters that support extensions
      def enable_extension(name)
      end

      # This is meant to be implemented by the adapters that support advisory
      # locks
      #
      # Return true if we got the lock, otherwise false
      def get_advisory_lock(lock_id) # :nodoc:
      end

      # This is meant to be implemented by the adapters that support advisory
      # locks.
      #
      # Return true if we released the lock, otherwise false
      def release_advisory_lock(lock_id) # :nodoc:
      end

      # A list of extensions, to be filled in by adapters that support them.
      def extensions
        []
      end

      # A list of index algorithms, to be filled by adapters that support them.
      def index_algorithms
        {}
      end

      # REFERENTIAL INTEGRITY ====================================

      # Override to turn off referential integrity while executing <tt>&block</tt>.
      def disable_referential_integrity
        yield
      end

      # CONNECTION MANAGEMENT ====================================

      # Checks whether the connection to the database is still active. This includes
      # checking whether the database is actually capable of responding, i.e. whether
      # the connection isn't stale.
      def active?
      end

      # Disconnects from the database if already connected, and establishes a
      # new connection with the database. Implementors should call super if they
      # override the default implementation.
      def reconnect!
        clear_cache!
        reset_transaction
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        clear_cache!
        reset_transaction
      end

      # Reset the state of this connection, directing the DBMS to clear
      # transactions and other connection-related server-side state. Usually a
      # database-dependent operation.
      #
      # The default implementation does nothing; the implementation should be
      # overridden by concrete adapters.
      def reset!
        # this should be overridden by concrete adapters
      end

      ###
      # Clear any caching the database adapter may be doing, for example
      # clearing the prepared statement cache. This is database specific.
      def clear_cache!
        # this should be overridden by concrete adapters
      end

      # Returns true if its required to reload the connection between requests for development mode.
      def requires_reloading?
        false
      end

      # Checks whether the connection to the database is still active (i.e. not stale).
      # This is done under the hood by calling #active?. If the connection
      # is no longer active, then this method will reconnect to the database.
      def verify!(*ignored)
        reconnect! unless active?
      end

      # Provides access to the underlying database driver for this adapter. For
      # example, this method returns a Mysql2::Client object in case of Mysql2Adapter,
      # and a PGconn object in case of PostgreSQLAdapter.
      #
      # This is useful for when you need to call a proprietary method such as
      # PostgreSQL's lo_* methods.
      def raw_connection
        @connection
      end

      def case_sensitive_comparison(table, attribute, column, value)
        if value.nil?
          table[attribute].eq(value)
        else
          table[attribute].eq(Arel::Nodes::BindParam.new)
        end
      end

      def case_insensitive_comparison(table, attribute, column, value)
        if can_perform_case_insensitive_comparison_for?(column)
          table[attribute].lower.eq(table.lower(Arel::Nodes::BindParam.new))
        else
          table[attribute].eq(Arel::Nodes::BindParam.new)
        end
      end

      def can_perform_case_insensitive_comparison_for?(column)
        true
      end
      private :can_perform_case_insensitive_comparison_for?

      # Check the connection back in to the connection pool
      def close
        pool.checkin self
      end

      def type_map # :nodoc:
        @type_map ||= Type::TypeMap.new.tap do |mapping|
          initialize_type_map(mapping)
        end
      end

      def new_column(name, default, sql_type_metadata, null, table_name, default_function = nil, collation = nil) # :nodoc:
        Column.new(name, default, sql_type_metadata, null, table_name, default_function, collation)
      end

      def lookup_cast_type(sql_type) # :nodoc:
        type_map.lookup(sql_type)
      end

      def column_name_for_operation(operation, node) # :nodoc:
        visitor.accept(node, collector).value
      end

      def combine_bind_parameters(
        from_clause: [],
        join_clause: [],
        where_clause: [],
        having_clause: [],
        limit: nil,
        offset: nil
      ) # :nodoc:
        result = from_clause + join_clause + where_clause + having_clause
        if limit
          result << limit
        end
        if offset
          result << offset
        end
        result
      end

      protected

        def initialize_type_map(m) # :nodoc:
          register_class_with_limit m, %r(boolean)i,       Type::Boolean
          register_class_with_limit m, %r(char)i,          Type::String
          register_class_with_limit m, %r(binary)i,        Type::Binary
          register_class_with_limit m, %r(text)i,          Type::Text
          register_class_with_precision m, %r(date)i,      Type::Date
          register_class_with_precision m, %r(time)i,      Type::Time
          register_class_with_precision m, %r(datetime)i,  Type::DateTime
          register_class_with_limit m, %r(float)i,         Type::Float
          register_class_with_limit m, %r(int)i,           Type::Integer

          m.alias_type %r(blob)i,      "binary"
          m.alias_type %r(clob)i,      "text"
          m.alias_type %r(timestamp)i, "datetime"
          m.alias_type %r(numeric)i,   "decimal"
          m.alias_type %r(number)i,    "decimal"
          m.alias_type %r(double)i,    "float"

          m.register_type(%r(decimal)i) do |sql_type|
            scale = extract_scale(sql_type)
            precision = extract_precision(sql_type)

            if scale == 0
              # FIXME: Remove this class as well
              Type::DecimalWithoutScale.new(precision: precision)
            else
              Type::Decimal.new(precision: precision, scale: scale)
            end
          end
        end

        def reload_type_map # :nodoc:
          type_map.clear
          initialize_type_map(type_map)
        end

        def register_class_with_limit(mapping, key, klass) # :nodoc:
          mapping.register_type(key) do |*args|
            limit = extract_limit(args.last)
            klass.new(limit: limit)
          end
        end

        def register_class_with_precision(mapping, key, klass) # :nodoc:
          mapping.register_type(key) do |*args|
            precision = extract_precision(args.last)
            klass.new(precision: precision)
          end
        end

        def extract_scale(sql_type) # :nodoc:
          case sql_type
          when /\((\d+)\)/ then 0
          when /\((\d+)(,(\d+))\)/ then $3.to_i
          end
        end

        def extract_precision(sql_type) # :nodoc:
          $1.to_i if sql_type =~ /\((\d+)(,\d+)?\)/
        end

        def extract_limit(sql_type) # :nodoc:
          case sql_type
          when /^bigint/i
            8
          when /\((.*)\)/
            $1.to_i
          end
        end

        def translate_exception_class(e, sql)
          begin
            message = "#{e.class.name}: #{e.message}: #{sql}"
          rescue Encoding::CompatibilityError
            message = "#{e.class.name}: #{e.message.force_encoding sql.encoding}: #{sql}"
          end

          exception = translate_exception(e, message)
          exception.set_backtrace e.backtrace
          exception
        end

        def log(sql, name = "SQL", binds = [], type_casted_binds = [], statement_name = nil)
          @instrumenter.instrument(
            "sql.active_record",
            sql:               sql,
            name:              name,
            binds:             binds,
            type_casted_binds: type_casted_binds,
            statement_name:    statement_name,
            connection_id:     object_id) { yield }
        rescue => e
          raise translate_exception_class(e, sql)
        end

        def translate_exception(exception, message)
          # override in derived class
          ActiveRecord::StatementInvalid.new(message)
        end

        def without_prepared_statement?(binds)
          !prepared_statements || binds.empty?
        end

        def column_for(table_name, column_name) # :nodoc:
          column_name = column_name.to_s
          columns(table_name).detect { |c| c.name == column_name } ||
            raise(ActiveRecordError, "No such column: #{table_name}.#{column_name}")
        end
    end
  end
end
