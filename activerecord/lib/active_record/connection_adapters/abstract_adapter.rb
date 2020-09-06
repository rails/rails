# frozen_string_literal: true

require 'set'
require 'active_record/connection_adapters/schema_cache'
require 'active_record/connection_adapters/sql_type_metadata'
require 'active_record/connection_adapters/abstract/schema_dumper'
require 'active_record/connection_adapters/abstract/schema_creation'
require 'active_support/concurrency/load_interlock_aware_monitor'
require 'arel/collectors/bind'
require 'arel/collectors/composite'
require 'arel/collectors/sql_string'
require 'arel/collectors/substitute_binds'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
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
      ADAPTER_NAME = 'Abstract'
      include ActiveSupport::Callbacks
      define_callbacks :checkout, :checkin

      include Quoting, DatabaseStatements, SchemaStatements
      include DatabaseLimits
      include QueryCache
      include Savepoints

      SIMPLE_INT = /\A\d+\z/
      COMMENT_REGEX = %r{/\*(?:[^\*]|\*[^/])*\*/}m

      attr_accessor :pool
      attr_reader :visitor, :owner, :logger, :lock
      alias :in_use? :owner

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
        if config == 'false'
          false
        else
          config
        end
      end

      DEFAULT_READ_QUERY = [:begin, :commit, :explain, :release, :rollback, :savepoint, :select, :with] # :nodoc:
      private_constant :DEFAULT_READ_QUERY

      def self.build_read_query_regexp(*parts) # :nodoc:
        parts += DEFAULT_READ_QUERY
        parts = parts.map { |part| /#{part}/i }
        /\A(?:[\(\s]|#{COMMENT_REGEX})*#{Regexp.union(*parts)}/
      end

      def self.quoted_column_names # :nodoc:
        @quoted_column_names ||= {}
      end

      def self.quoted_table_names # :nodoc:
        @quoted_table_names ||= {}
      end

      def initialize(connection, logger = nil, config = {}) # :nodoc:
        super()

        @connection          = connection
        @owner               = nil
        @instrumenter        = ActiveSupport::Notifications.instrumenter
        @logger              = logger
        @config              = config
        @pool                = ActiveRecord::ConnectionAdapters::NullPool.new
        @idle_since          = Concurrent.monotonic_time
        @visitor = arel_visitor
        @statements = build_statement_pool
        @lock = ActiveSupport::Concurrency::LoadInterlockAwareMonitor.new

        @prepared_statements = self.class.type_cast_config_to_boolean(
          config.fetch(:prepared_statements, true)
        )

        @advisory_locks_enabled = self.class.type_cast_config_to_boolean(
          config.fetch(:advisory_locks, true)
        )
      end

      def replica?
        @config[:replica] || false
      end

      def use_metadata_table?
        @config.fetch(:use_metadata_table, true)
      end

      # Determines whether writes are currently being prevents.
      #
      # Returns true if the connection is a replica, or if +prevent_writes+
      # is set to true.
      def preventing_writes?
        replica? || ActiveRecord::Base.connection_handler.prevent_writes
      end

      def migrations_paths # :nodoc:
        @config[:migrations_paths] || Migrator.migrations_paths
      end

      def migration_context # :nodoc:
        MigrationContext.new(migrations_paths, schema_migration)
      end

      def schema_migration # :nodoc:
        @schema_migration ||= begin
                                conn = self
                                spec_name = conn.pool.pool_config.connection_specification_name

                                return ActiveRecord::SchemaMigration if spec_name == 'ActiveRecord::Base'

                                schema_migration_name = "#{spec_name}::SchemaMigration"

                                Class.new(ActiveRecord::SchemaMigration) do
                                  define_singleton_method(:name) { schema_migration_name }
                                  define_singleton_method(:to_s) { schema_migration_name }

                                  self.connection_specification_name = spec_name
                                end
                              end
      end

      def prepared_statements
        @prepared_statements && !prepared_statements_disabled_cache.include?(object_id)
      end

      def prepared_statements_disabled_cache # :nodoc:
        Thread.current[:ar_prepared_statements_disabled_cache] ||= Set.new
      end

      class Version
        include Comparable

        attr_reader :full_version_string

        def initialize(version_string, full_version_string = nil)
          @version = version_string.split('.').map(&:to_i)
          @full_version_string = full_version_string
        end

        def <=>(version_string)
          @version <=> version_string.split('.').map(&:to_i)
        end

        def to_s
          @version.join('.')
        end
      end

      def valid_type?(type) # :nodoc:
        !native_database_types[type].nil?
      end

      # this method must only be called while holding connection pool's mutex
      def lease
        if in_use?
          msg = +'Cannot lease connection, '
          if @owner == Thread.current
            msg << 'it is already leased by the current thread.'
          else
            msg << "it is already in use by a different thread: #{@owner}. " \
                   "Current thread: #{Thread.current}."
          end
          raise ActiveRecordError, msg
        end

        @owner = Thread.current
      end

      def schema_cache
        @pool.get_schema_cache(self)
      end

      def schema_cache=(cache)
        cache.connection = self
        @pool.set_schema_cache(cache)
      end

      # this method must only be called while holding connection pool's mutex
      def expire
        if in_use?
          if @owner != Thread.current
            raise ActiveRecordError, 'Cannot expire connection, ' \
              "it is owned by a different thread: #{@owner}. " \
              "Current thread: #{Thread.current}."
          end

          @idle_since = Concurrent.monotonic_time
          @owner = nil
        else
          raise ActiveRecordError, 'Cannot expire connection, it is not currently leased.'
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
          raise ActiveRecordError, 'Cannot steal connection, it is not currently leased.'
        end
      end

      # Seconds since this connection was returned to the pool
      def seconds_idle # :nodoc:
        return 0 if in_use?
        Concurrent.monotonic_time - @idle_since
      end

      def unprepared_statement
        cache = prepared_statements_disabled_cache.add(object_id) if @prepared_statements
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
        raise NotImplementedError
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

      # Does this adapter support creating foreign key constraints
      # in the same statement as creating the table?
      def supports_foreign_keys_in_create?
        supports_foreign_keys?
      end
      deprecate :supports_foreign_keys_in_create?

      # Does this adapter support creating check constraints?
      def supports_check_constraints?
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
      deprecate :supports_multi_insert?

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

      # This is meant to be implemented by the adapters that support extensions
      def disable_extension(name)
      end

      # This is meant to be implemented by the adapters that support extensions
      def enable_extension(name)
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

      # Immediately forget this connection ever existed. Unlike disconnect!,
      # this will not communicate with the server.
      #
      # After calling this method, the behavior of all other methods becomes
      # undefined. This is called internally just before a forked process gets
      # rid of a connection that belonged to its parent.
      def discard!
        # This should be overridden by concrete adapters.
        #
        # Prevent @connection's finalizer from touching the socket, or
        # otherwise communicating with its server, when it is collected.
        if schema_cache.connection == self
          schema_cache.connection = nil
        end
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

      # Clear any caching the database adapter may be doing.
      def clear_cache!
        @lock.synchronize { @statements.clear } if @statements
      end

      # Returns true if its required to reload the connection between requests for development mode.
      def requires_reloading?
        false
      end

      # Checks whether the connection to the database is still active (i.e. not stale).
      # This is done under the hood by calling #active?. If the connection
      # is no longer active, then this method will reconnect to the database.
      def verify!
        reconnect! unless active?
      end

      # Provides access to the underlying database driver for this adapter. For
      # example, this method returns a Mysql2::Client object in case of Mysql2Adapter,
      # and a PG::Connection object in case of PostgreSQLAdapter.
      #
      # This is useful for when you need to call a proprietary method such as
      # PostgreSQL's lo_* methods.
      def raw_connection
        disable_lazy_transactions!
        @connection
      end

      def default_uniqueness_comparison(attribute, value, klass) # :nodoc:
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

      private
        def type_map
          @type_map ||= Type::TypeMap.new.tap do |mapping|
            initialize_type_map(mapping)
          end
        end

        def initialize_type_map(m = type_map)
          register_class_with_limit m, %r(boolean)i,       Type::Boolean
          register_class_with_limit m, %r(char)i,          Type::String
          register_class_with_limit m, %r(binary)i,        Type::Binary
          register_class_with_limit m, %r(text)i,          Type::Text
          register_class_with_precision m, %r(date)i,      Type::Date
          register_class_with_precision m, %r(time)i,      Type::Time
          register_class_with_precision m, %r(datetime)i,  Type::DateTime
          register_class_with_limit m, %r(float)i,         Type::Float
          register_class_with_limit m, %r(int)i,           Type::Integer

          m.alias_type %r(blob)i,      'binary'
          m.alias_type %r(clob)i,      'text'
          m.alias_type %r(timestamp)i, 'datetime'
          m.alias_type %r(numeric)i,   'decimal'
          m.alias_type %r(number)i,    'decimal'
          m.alias_type %r(double)i,    'float'

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

        def reload_type_map
          type_map.clear
          initialize_type_map
        end

        def register_class_with_limit(mapping, key, klass)
          mapping.register_type(key) do |*args|
            limit = extract_limit(args.last)
            klass.new(limit: limit)
          end
        end

        def register_class_with_precision(mapping, key, klass)
          mapping.register_type(key) do |*args|
            precision = extract_precision(args.last)
            klass.new(precision: precision)
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

        def translate_exception_class(e, sql, binds)
          message = "#{e.class.name}: #{e.message}"

          exception = translate_exception(
            e, message: message, sql: sql, binds: binds
          )
          exception.set_backtrace e.backtrace
          exception
        end

        def log(sql, name = 'SQL', binds = [], type_casted_binds = [], statement_name = nil) # :doc:
          @instrumenter.instrument(
            'sql.active_record',
            sql:               sql,
            name:              name,
            binds:             binds,
            type_casted_binds: type_casted_binds,
            statement_name:    statement_name,
            connection:        self) do
            @lock.synchronize do
              yield
            end
          rescue => e
            raise translate_exception_class(e, sql, binds)
          end
        end

        def translate_exception(exception, message:, sql:, binds:)
          # override in derived class
          case exception
          when RuntimeError
            exception
          else
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
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
    end
  end
end
