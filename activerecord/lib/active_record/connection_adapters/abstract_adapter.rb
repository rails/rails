# frozen_string_literal: true

require "set"
require "active_record/connection_adapters/sql_type_metadata"
require "active_record/connection_adapters/abstract/schema_dumper"
require "active_record/connection_adapters/abstract/schema_creation"
require "active_support/concurrency/null_lock"
require "active_support/concurrency/load_interlock_aware_monitor"
require "arel/collectors/bind"
require "arel/collectors/composite"
require "arel/collectors/sql_string"
require "arel/collectors/substitute_binds"

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # = Active Record Abstract Adapter
    #
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
      ADAPTER_NAME = "Abstract"
      include ActiveSupport::Callbacks
      define_callbacks :checkout, :checkin

      include Quoting, DatabaseStatements, SchemaStatements
      include DatabaseLimits
      include QueryCache
      include Savepoints

      SIMPLE_INT = /\A\d+\z/
      COMMENT_REGEX = %r{(?:--.*\n)|/\*(?:[^*]|\*[^/])*\*/}

      attr_reader :pool
      attr_reader :visitor, :owner, :logger, :lock
      alias :in_use? :owner

      def pool=(value)
        return if value.eql?(@pool)
        @schema_cache = nil
        @pool = value

        @pool.schema_reflection.load!(self) if ActiveRecord.lazily_load_schema_cache
      end

      set_callback :checkin, :after, :enable_lazy_transactions!

      def self.type_cast_config_to_integer(config)
        if config.is_a?(Integer)
          config
        elsif SIMPLE_INT.match?(config)
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

      def self.validate_default_timezone(config)
        case config
        when nil
        when "utc", "local"
          config.to_sym
        else
          raise ArgumentError, "default_timezone must be either 'utc' or 'local'"
        end
      end

      DEFAULT_READ_QUERY = [:begin, :commit, :explain, :release, :rollback, :savepoint, :select, :with] # :nodoc:
      private_constant :DEFAULT_READ_QUERY

      def self.build_read_query_regexp(*parts) # :nodoc:
        parts += DEFAULT_READ_QUERY
        parts = parts.map { |part| /#{part}/i }
        /\A(?:[(\s]|#{COMMENT_REGEX})*#{Regexp.union(*parts)}/
      end

      def self.find_cmd_and_exec(commands, *args) # :doc:
        commands = Array(commands)

        dirs_on_path = ENV["PATH"].to_s.split(File::PATH_SEPARATOR)
        unless (ext = RbConfig::CONFIG["EXEEXT"]).empty?
          commands = commands.map { |cmd| "#{cmd}#{ext}" }
        end

        full_path_command = nil
        found = commands.detect do |cmd|
          dirs_on_path.detect do |path|
            full_path_command = File.join(path, cmd)
            begin
              stat = File.stat(full_path_command)
            rescue SystemCallError
            else
              stat.file? && stat.executable?
            end
          end
        end

        if found
          exec full_path_command, *args
        else
          abort("Couldn't find database client: #{commands.join(', ')}. Check your $PATH and try again.")
        end
      end

      # Opens a database console session.
      def self.dbconsole(config, options = {})
        raise NotImplementedError
      end

      def initialize(config_or_deprecated_connection, deprecated_logger = nil, deprecated_connection_options = nil, deprecated_config = nil) # :nodoc:
        super()

        @raw_connection = nil
        @unconfigured_connection = nil

        if config_or_deprecated_connection.is_a?(Hash)
          @config = config_or_deprecated_connection.symbolize_keys
          @logger = ActiveRecord::Base.logger

          if deprecated_logger || deprecated_connection_options || deprecated_config
            raise ArgumentError, "when initializing an ActiveRecord adapter with a config hash, that should be the only argument"
          end
        else
          # Soft-deprecated for now; we'll probably warn in future.

          @unconfigured_connection = config_or_deprecated_connection
          @logger = deprecated_logger || ActiveRecord::Base.logger
          if deprecated_config
            @config = (deprecated_config || {}).symbolize_keys
            @connection_parameters = deprecated_connection_options
          else
            @config = (deprecated_connection_options || {}).symbolize_keys
            @connection_parameters = nil
          end
        end

        @owner = nil
        @instrumenter = ActiveSupport::Notifications.instrumenter
        @pool = ActiveRecord::ConnectionAdapters::NullPool.new
        @idle_since = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @visitor = arel_visitor
        @statements = build_statement_pool
        self.lock_thread = nil

        @prepared_statements = !ActiveRecord.disable_prepared_statements && self.class.type_cast_config_to_boolean(
          @config.fetch(:prepared_statements) { default_prepared_statements }
        )

        @advisory_locks_enabled = self.class.type_cast_config_to_boolean(
          @config.fetch(:advisory_locks, true)
        )

        @default_timezone = self.class.validate_default_timezone(@config[:default_timezone])

        @raw_connection_dirty = false
        @verified = false
      end

      THREAD_LOCK = ActiveSupport::Concurrency::ThreadLoadInterlockAwareMonitor.new
      private_constant :THREAD_LOCK

      FIBER_LOCK = ActiveSupport::Concurrency::LoadInterlockAwareMonitor.new
      private_constant :FIBER_LOCK

      def lock_thread=(lock_thread) # :nodoc:
        @lock =
        case lock_thread
        when Thread
          THREAD_LOCK
        when Fiber
          FIBER_LOCK
        else
          ActiveSupport::Concurrency::NullLock
        end
      end

      EXCEPTION_NEVER = { Exception => :never }.freeze # :nodoc:
      EXCEPTION_IMMEDIATE = { Exception => :immediate }.freeze # :nodoc:
      private_constant :EXCEPTION_NEVER, :EXCEPTION_IMMEDIATE
      def with_instrumenter(instrumenter, &block) # :nodoc:
        Thread.handle_interrupt(EXCEPTION_NEVER) do
          previous_instrumenter = @instrumenter
          @instrumenter = instrumenter
          Thread.handle_interrupt(EXCEPTION_IMMEDIATE, &block)
        ensure
          @instrumenter = previous_instrumenter
        end
      end

      def check_if_write_query(sql) # :nodoc:
        if preventing_writes? && write_query?(sql)
          raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
        end
      end

      def replica?
        @config[:replica] || false
      end

      def use_metadata_table?
        @config.fetch(:use_metadata_table, true)
      end

      def connection_retries
        (@config[:connection_retries] || 1).to_i
      end

      def retry_deadline
        if @config[:retry_deadline]
          @config[:retry_deadline].to_f
        else
          nil
        end
      end

      def default_timezone
        @default_timezone || ActiveRecord.default_timezone
      end

      # Determines whether writes are currently being prevented.
      #
      # Returns true if the connection is a replica or returns
      # the value of +current_preventing_writes+.
      def preventing_writes?
        return true if replica?
        return false if connection_class.nil?

        connection_class.current_preventing_writes
      end

      def migrations_paths # :nodoc:
        @config[:migrations_paths] || Migrator.migrations_paths
      end

      def migration_context # :nodoc:
        MigrationContext.new(migrations_paths, schema_migration, internal_metadata)
      end

      def schema_migration # :nodoc:
        SchemaMigration.new(self)
      end

      def internal_metadata # :nodoc:
        InternalMetadata.new(self)
      end

      def prepared_statements?
        @prepared_statements && !prepared_statements_disabled_cache.include?(object_id)
      end
      alias :prepared_statements :prepared_statements?

      def prepared_statements_disabled_cache # :nodoc:
        ActiveSupport::IsolatedExecutionState[:active_record_prepared_statements_disabled_cache] ||= Set.new
      end

      class Version
        include Comparable

        attr_reader :full_version_string

        def initialize(version_string, full_version_string = nil)
          @version = version_string.split(".").map(&:to_i)
          @full_version_string = full_version_string
        end

        def <=>(version_string)
          @version <=> version_string.split(".").map(&:to_i)
        end

        def to_s
          @version.join(".")
        end
      end

      def valid_type?(type) # :nodoc:
        !native_database_types[type].nil?
      end

      # this method must only be called while holding connection pool's mutex
      def lease
        if in_use?
          msg = +"Cannot lease connection, "
          if @owner == ActiveSupport::IsolatedExecutionState.context
            msg << "it is already leased by the current thread."
          else
            msg << "it is already in use by a different thread: #{@owner}. " \
                   "Current thread: #{ActiveSupport::IsolatedExecutionState.context}."
          end
          raise ActiveRecordError, msg
        end

        @owner = ActiveSupport::IsolatedExecutionState.context
      end

      def connection_class # :nodoc:
        @pool.connection_class
      end

      # The role (e.g. +:writing+) for the current connection. In a
      # non-multi role application, +:writing+ is returned.
      def role
        @pool.role
      end

      # The shard (e.g. +:default+) for the current connection. In
      # a non-sharded application, +:default+ is returned.
      def shard
        @pool.shard
      end

      def schema_cache
        @schema_cache ||= BoundSchemaReflection.new(@pool.schema_reflection, self)
      end

      # this method must only be called while holding connection pool's mutex
      def expire
        if in_use?
          if @owner != ActiveSupport::IsolatedExecutionState.context
            raise ActiveRecordError, "Cannot expire connection, " \
              "it is owned by a different thread: #{@owner}. " \
              "Current thread: #{ActiveSupport::IsolatedExecutionState.context}."
          end

          @idle_since = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @owner = nil
        else
          raise ActiveRecordError, "Cannot expire connection, it is not currently leased."
        end
      end

      # this method must only be called while holding connection pool's mutex (and a desire for segfaults)
      def steal! # :nodoc:
        if in_use?
          if @owner != ActiveSupport::IsolatedExecutionState.context
            pool.send :remove_connection_from_thread_cache, self, @owner

            @owner = ActiveSupport::IsolatedExecutionState.context
          end
        else
          raise ActiveRecordError, "Cannot steal connection, it is not currently leased."
        end
      end

      # Seconds since this connection was returned to the pool
      def seconds_idle # :nodoc:
        return 0 if in_use?
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - @idle_since
      end

      def unprepared_statement
        cache = prepared_statements_disabled_cache.add?(object_id) if @prepared_statements
        yield
      ensure
        cache&.delete(object_id)
      end

      # Returns the human-readable name of the adapter. Use mixed case - one
      # can always use downcase if needed.
      def adapter_name
        self.class::ADAPTER_NAME
      end

      # Does the database for this adapter exist?
      def self.database_exists?(config)
        new(config).database_exists?
      end

      def database_exists?
        connect!
        true
      rescue ActiveRecord::NoDatabaseError
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

      # Do TransactionRollbackErrors on savepoints affect the parent
      # transaction?
      def savepoint_errors_invalidate_transactions?
        false
      end

      def supports_restart_db_transaction?
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

      def supports_partitioned_indexes?
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

      # Does this adapter support including non-key columns?
      def supports_index_include?
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

      # Does this adapter support creating invalid constraints?
      def supports_validate_constraints?
        false
      end

      # Does this adapter support creating deferrable constraints?
      def supports_deferrable_constraints?
        false
      end

      # Does this adapter support creating check constraints?
      def supports_check_constraints?
        false
      end

      # Does this adapter support creating exclusion constraints?
      def supports_exclusion_constraints?
        false
      end

      # Does this adapter support creating unique constraints?
      def supports_unique_constraints?
        false
      end

      # Does this adapter support views?
      def supports_views?
        false
      end

      # Does this adapter support materialized views?
      def supports_materialized_views?
        false
      end

      # Does this adapter support datetime with precision?
      def supports_datetime_with_precision?
        false
      end

      # Does this adapter support JSON data type?
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

      # Does this adapter support virtual columns?
      def supports_virtual_columns?
        false
      end

      # Does this adapter support foreign/external tables?
      def supports_foreign_tables?
        false
      end

      # Does this adapter support optimizer hints?
      def supports_optimizer_hints?
        false
      end

      def supports_common_table_expressions?
        false
      end

      def supports_lazy_transactions?
        false
      end

      def supports_insert_returning?
        false
      end

      def supports_insert_on_duplicate_skip?
        false
      end

      def supports_insert_on_duplicate_update?
        false
      end

      def supports_insert_conflict_target?
        false
      end

      def supports_concurrent_connections?
        true
      end

      def supports_nulls_not_distinct?
        false
      end

      def return_value_after_insert?(column) # :nodoc:
        column.auto_incremented_by_db?
      end

      def async_enabled? # :nodoc:
        supports_concurrent_connections? &&
          !ActiveRecord.async_query_executor.nil? && !pool.async_executor.nil?
      end

      # This is meant to be implemented by the adapters that support extensions
      def disable_extension(name, **)
      end

      # This is meant to be implemented by the adapters that support extensions
      def enable_extension(name, **)
      end

      # This is meant to be implemented by the adapters that support custom enum types
      def create_enum(*) # :nodoc:
      end

      # This is meant to be implemented by the adapters that support custom enum types
      def drop_enum(*) # :nodoc:
      end

      # This is meant to be implemented by the adapters that support custom enum types
      def rename_enum(*) # :nodoc:
      end

      # This is meant to be implemented by the adapters that support custom enum types
      def add_enum_value(*) # :nodoc:
      end

      # This is meant to be implemented by the adapters that support custom enum types
      def rename_enum_value(*) # :nodoc:
      end

      def advisory_locks_enabled? # :nodoc:
        supports_advisory_locks? && @advisory_locks_enabled
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

      # Override to check all foreign key constraints in a database.
      def all_foreign_keys_valid?
        check_all_foreign_keys_valid!
        true
      rescue ActiveRecord::StatementInvalid
        false
      end
      deprecate :all_foreign_keys_valid?, deprecator: ActiveRecord.deprecator

      # Override to check all foreign key constraints in a database.
      # The adapter should raise a +ActiveRecord::StatementInvalid+ if foreign key
      # constraints are not met.
      def check_all_foreign_keys_valid!
      end

      # CONNECTION MANAGEMENT ====================================

      # Checks whether the connection to the database is still active. This includes
      # checking whether the database is actually capable of responding, i.e. whether
      # the connection isn't stale.
      def active?
      end

      # Disconnects from the database if already connected, and establishes a new
      # connection with the database. Implementors should define private #reconnect
      # instead.
      def reconnect!(restore_transactions: false)
        retries_available = connection_retries
        deadline = retry_deadline && Process.clock_gettime(Process::CLOCK_MONOTONIC) + retry_deadline

        @lock.synchronize do
          reconnect

          enable_lazy_transactions!
          @raw_connection_dirty = false
          @verified = true

          reset_transaction(restore: restore_transactions) do
            clear_cache!(new_connection: true)
            configure_connection
          end
        rescue => original_exception
          translated_exception = translate_exception_class(original_exception, nil, nil)
          retry_deadline_exceeded = deadline && deadline < Process.clock_gettime(Process::CLOCK_MONOTONIC)

          if !retry_deadline_exceeded && retries_available > 0
            retries_available -= 1

            if retryable_connection_error?(translated_exception)
              backoff(connection_retries - retries_available)
              retry
            end
          end

          @verified = false

          raise translated_exception
        end
      end


      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        clear_cache!(new_connection: true)
        reset_transaction
        @raw_connection_dirty = false
      end

      # Immediately forget this connection ever existed. Unlike disconnect!,
      # this will not communicate with the server.
      #
      # After calling this method, the behavior of all other methods becomes
      # undefined. This is called internally just before a forked process gets
      # rid of a connection that belonged to its parent.
      def discard!
        # This should be overridden by concrete adapters.
      end

      # Reset the state of this connection, directing the DBMS to clear
      # transactions and other connection-related server-side state. Usually a
      # database-dependent operation.
      #
      # If a database driver or protocol does not support such a feature,
      # implementors may alias this to #reconnect!. Otherwise, implementors
      # should call super immediately after resetting the connection (and while
      # still holding @lock).
      def reset!
        clear_cache!(new_connection: true)
        reset_transaction
        configure_connection
      end

      # Removes the connection from the pool and disconnect it.
      def throw_away!
        pool.remove self
        disconnect!
      end

      # Clear any caching the database adapter may be doing.
      def clear_cache!(new_connection: false)
        if @statements
          @lock.synchronize do
            if new_connection
              @statements.reset
            else
              @statements.clear
            end
          end
        end
      end

      # Returns true if its required to reload the connection between requests for development mode.
      def requires_reloading?
        false
      end

      # Checks whether the connection to the database is still active (i.e. not stale).
      # This is done under the hood by calling #active?. If the connection
      # is no longer active, then this method will reconnect to the database.
      def verify!
        unless active?
          if @unconfigured_connection
            @lock.synchronize do
              if @unconfigured_connection
                @raw_connection = @unconfigured_connection
                @unconfigured_connection = nil
                configure_connection
                @verified = true
                return
              end
            end
          end

          reconnect!(restore_transactions: true)
        end

        @verified = true
      end

      def connect!
        verify!
        self
      end

      def clean! # :nodoc:
        @raw_connection_dirty = false
        @verified = nil
      end

      # Provides access to the underlying database driver for this adapter. For
      # example, this method returns a Mysql2::Client object in case of Mysql2Adapter,
      # and a PG::Connection object in case of PostgreSQLAdapter.
      #
      # This is useful for when you need to call a proprietary method such as
      # PostgreSQL's lo_* methods.
      #
      # Active Record cannot track if the database is getting modified using
      # this client. If that is the case, generally you'll want to invalidate
      # the query cache using +ActiveRecord::Base.clear_query_cache+.
      def raw_connection
        with_raw_connection do |conn|
          disable_lazy_transactions!
          @raw_connection_dirty = true
          conn
        end
      end

      def default_uniqueness_comparison(attribute, value) # :nodoc:
        attribute.eq(value)
      end

      def case_sensitive_comparison(attribute, value) # :nodoc:
        attribute.eq(value)
      end

      def case_insensitive_comparison(attribute, value) # :nodoc:
        column = column_for_attribute(attribute)

        if can_perform_case_insensitive_comparison_for?(column)
          attribute.lower.eq(attribute.relation.lower(value))
        else
          attribute.eq(value)
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

      def default_index_type?(index) # :nodoc:
        index.using.nil?
      end

      # Called by ActiveRecord::InsertAll,
      # Passed an instance of ActiveRecord::InsertAll::Builder,
      # This method implements standard bulk inserts for all databases, but
      # should be overridden by adapters to implement common features with
      # non-standard syntax like handling duplicates or returning values.
      def build_insert_sql(insert) # :nodoc:
        if insert.skip_duplicates? || insert.update_duplicates?
          raise NotImplementedError, "#{self.class} should define `build_insert_sql` to implement adapter-specific logic for handling duplicates during INSERT"
        end

        "INSERT #{insert.into} #{insert.values_list}"
      end

      def get_database_version # :nodoc:
      end

      def database_version # :nodoc:
        schema_cache.database_version
      end

      def check_version # :nodoc:
      end

      # Returns the version identifier of the schema currently available in
      # the database. This is generally equal to the number of the highest-
      # numbered migration that has been executed, or 0 if no schema
      # information is present / the database is empty.
      def schema_version
        migration_context.current_version
      end

      class << self
        def register_class_with_precision(mapping, key, klass, **kwargs) # :nodoc:
          mapping.register_type(key) do |*args|
            precision = extract_precision(args.last)
            klass.new(precision: precision, **kwargs)
          end
        end

        def extended_type_map(default_timezone:) # :nodoc:
          Type::TypeMap.new(self::TYPE_MAP).tap do |m|
            register_class_with_precision m, %r(\A[^\(]*time)i, Type::Time, timezone: default_timezone
            register_class_with_precision m, %r(\A[^\(]*datetime)i, Type::DateTime, timezone: default_timezone
            m.alias_type %r(\A[^\(]*timestamp)i, "datetime"
          end
        end

        private
          def initialize_type_map(m)
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

            m.register_type %r(^json)i, Type::Json.new

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

          def register_class_with_limit(mapping, key, klass)
            mapping.register_type(key) do |*args|
              limit = extract_limit(args.last)
              klass.new(limit: limit)
            end
          end

          def extract_scale(sql_type)
            case sql_type
            when /\((\d+)\)/ then 0
            when /\((\d+)(,(\d+))\)/ then $3.to_i
            end
          end

          def extract_precision(sql_type)
            $1.to_i if sql_type =~ /\((\d+)(,\d+)?\)/
          end

          def extract_limit(sql_type)
            $1.to_i if sql_type =~ /\((.*)\)/
          end
      end

      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) }
      EXTENDED_TYPE_MAPS = Concurrent::Map.new

      private
        def reconnect_can_restore_state?
          transaction_manager.restorable? && !@raw_connection_dirty
        end

        # Lock the monitor, ensure we're properly connected and
        # transactions are materialized, and then yield the underlying
        # raw connection object.
        #
        # If +allow_retry+ is true, a connection-related exception will
        # cause an automatic reconnect and re-run of the block, up to
        # the connection's configured +connection_retries+ setting
        # and the configured +retry_deadline+ limit. (Note that when
        # +allow_retry+ is true, it's possible to return without having marked
        # the connection as verified. If the block is guaranteed to exercise the
        # connection, consider calling `verified!` to avoid needless
        # verification queries in subsequent calls.)
        #
        # If +materialize_transactions+ is false, the block will be run without
        # ensuring virtual transactions have been materialized in the DB
        # server's state. The active transaction will also remain clean
        # (if it is not already dirty), meaning it's able to be restored
        # by reconnecting and opening an equivalent-depth set of new
        # transactions. This should only be used by transaction control
        # methods, and internal transaction-agnostic queries.
        #
        ###
        #
        # It's not the primary use case, so not something to optimize
        # for, but note that this method does need to be re-entrant:
        # +materialize_transactions+ will re-enter if it has work to do,
        # and the yield block can also do so under some circumstances.
        #
        # In the latter case, we really ought to guarantee the inner
        # call will not reconnect (which would interfere with the
        # still-yielded connection in the outer block), but we currently
        # provide no special enforcement there.
        #
        def with_raw_connection(allow_retry: false, materialize_transactions: true)
          @lock.synchronize do
            connect! if @raw_connection.nil? && reconnect_can_restore_state?

            self.materialize_transactions if materialize_transactions

            retries_available = allow_retry ? connection_retries : 0
            deadline = retry_deadline && Process.clock_gettime(Process::CLOCK_MONOTONIC) + retry_deadline
            reconnectable = reconnect_can_restore_state?

            if @verified
              # Cool, we're confident the connection's ready to use. (Note this might have
              # become true during the above #materialize_transactions.)
            elsif reconnectable
              if allow_retry
                # Not sure about the connection yet, but if anything goes wrong we can
                # just reconnect and re-run our query
              else
                # We can reconnect if needed, but we don't trust the upcoming query to be
                # safely re-runnable: let's verify the connection to be sure
                verify!
              end
            else
              # We don't know whether the connection is okay, but it also doesn't matter:
              # we wouldn't be able to reconnect anyway. We're just going to run our query
              # and hope for the best.
            end

            begin
              yield @raw_connection
            rescue => original_exception
              translated_exception = translate_exception_class(original_exception, nil, nil)
              invalidate_transaction(translated_exception)
              retry_deadline_exceeded = deadline && deadline < Process.clock_gettime(Process::CLOCK_MONOTONIC)

              if !retry_deadline_exceeded && retries_available > 0
                retries_available -= 1

                if retryable_query_error?(translated_exception)
                  backoff(connection_retries - retries_available)
                  retry
                elsif reconnectable && retryable_connection_error?(translated_exception)
                  reconnect!(restore_transactions: true)
                  # Only allowed to reconnect once, because reconnect! has its own retry
                  # loop
                  reconnectable = false
                  retry
                end
              end

              unless retryable_query_error?(translated_exception)
                # Barring a known-retryable error inside the query (regardless of
                # whether we were in a _position_ to retry it), we should infer that
                # there's likely a real problem with the connection.
                @verified = false
              end

              raise translated_exception
            ensure
              dirty_current_transaction if materialize_transactions
            end
          end
        end

        # Mark the connection as verified. Call this inside a
        # `with_raw_connection` block only when the block is guaranteed to
        # exercise the raw connection.
        def verified!
          @verified = true
        end

        def retryable_connection_error?(exception)
          exception.is_a?(ConnectionNotEstablished) || exception.is_a?(ConnectionFailed)
        end

        def invalidate_transaction(exception)
          return unless exception.is_a?(TransactionRollbackError)
          return unless savepoint_errors_invalidate_transactions?

          current_transaction.invalidate!
        end

        def retryable_query_error?(exception)
          # We definitely can't retry if we were inside an invalidated transaction.
          return false if current_transaction.invalidated?

          exception.is_a?(Deadlocked) || exception.is_a?(LockWaitTimeout)
        end

        def backoff(counter)
          sleep 0.1 * counter
        end

        def reconnect
          raise NotImplementedError
        end

        # Returns a raw connection for internal use with methods that are known
        # to both be thread-safe and not rely upon actual server communication.
        # This is useful for e.g. string escaping methods.
        def any_raw_connection
          @raw_connection || valid_raw_connection
        end

        # Similar to any_raw_connection, but ensures it is validated and
        # connected. Any method called on this result still needs to be
        # independently thread-safe, so it probably shouldn't talk to the
        # server... but some drivers fail if they know the connection has gone
        # away.
        def valid_raw_connection
          (@verified && @raw_connection) ||
            # `allow_retry: false`, to force verification: the block won't
            # raise, so a retry wouldn't help us get the valid connection we
            # need.
            with_raw_connection(allow_retry: false, materialize_transactions: false) { |conn| conn }
        end

        def extended_type_map_key
          if @default_timezone
            { default_timezone: @default_timezone }
          end
        end

        def type_map
          if key = extended_type_map_key
            self.class::EXTENDED_TYPE_MAPS.compute_if_absent(key) do
              self.class.extended_type_map(**key)
            end
          else
            self.class::TYPE_MAP
          end
        end

        def translate_exception_class(e, sql, binds)
          message = "#{e.class.name}: #{e.message}"

          exception = translate_exception(
            e, message: message, sql: sql, binds: binds
          )
          exception.set_backtrace e.backtrace
          exception
        end

        def log(sql, name = "SQL", binds = [], type_casted_binds = [], statement_name = nil, async: false, &block) # :doc:
          @instrumenter.instrument(
            "sql.active_record",
            sql:               sql,
            name:              name,
            binds:             binds,
            type_casted_binds: type_casted_binds,
            statement_name:    statement_name,
            async:             async,
            connection:        self,
            &block
          )
        rescue ActiveRecord::StatementInvalid => ex
          raise ex.set_query(sql, binds)
        end

        def transform_query(sql)
          ActiveRecord.query_transformers.each do |transformer|
            sql = transformer.call(sql, self)
          end
          sql
        end

        def translate_exception(exception, message:, sql:, binds:)
          # override in derived class
          case exception
          when RuntimeError, ActiveRecord::ActiveRecordError
            exception
          else
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
          end
        end

        def without_prepared_statement?(binds)
          !prepared_statements || binds.empty?
        end

        def column_for(table_name, column_name)
          column_name = column_name.to_s
          columns(table_name).detect { |c| c.name == column_name } ||
            raise(ActiveRecordError, "No such column: #{table_name}.#{column_name}")
        end

        def column_for_attribute(attribute)
          table_name = attribute.relation.name
          schema_cache.columns_hash(table_name)[attribute.name.to_s]
        end

        def collector
          if prepared_statements
            Arel::Collectors::Composite.new(
              Arel::Collectors::SQLString.new,
              Arel::Collectors::Bind.new,
            )
          else
            Arel::Collectors::SubstituteBinds.new(
              self,
              Arel::Collectors::SQLString.new,
            )
          end
        end

        def arel_visitor
          Arel::Visitors::ToSql.new(self)
        end

        def build_statement_pool
        end

        # Builds the result object.
        #
        # This is an internal hook to make possible connection adapters to build
        # custom result objects with connection-specific data.
        def build_result(columns:, rows:, column_types: {})
          ActiveRecord::Result.new(columns, rows, column_types)
        end

        # Perform any necessary initialization upon the newly-established
        # @raw_connection -- this is the place to modify the adapter's
        # connection settings, run queries to configure any application-global
        # "session" variables, etc.
        #
        # Implementations may assume this method will only be called while
        # holding @lock (or from #initialize).
        def configure_connection
        end

        def default_prepared_statements
          true
        end

        def warning_ignored?(warning)
          ActiveRecord.db_warnings_ignore.any? do |warning_matcher|
            warning.message.match?(warning_matcher) || warning.code.to_s.match?(warning_matcher)
          end
        end
    end
  end
end
