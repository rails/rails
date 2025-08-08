# frozen_string_literal: true

#--
# Copyright (c) David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require "active_support"
require "active_support/rails"
require "active_support/ordered_options"
require "active_model"
require "arel"
require "yaml"
require "zlib"

require "active_record/version"
require "active_record/deprecator"
require "active_model/attribute_set"
require "active_record/errors"

# :include: ../README.rdoc
module ActiveRecord
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Callbacks
  autoload :ConnectionHandling
  autoload :Core
  autoload :CounterCache
  autoload :DelegatedType
  autoload :DestroyAssociationAsyncJob
  autoload :DynamicMatchers
  autoload :Encryption
  autoload :Enum
  autoload :Explain
  autoload :FixtureSet, "active_record/fixtures"
  autoload :Inheritance
  autoload :Integration
  autoload :InternalMetadata
  autoload :LogSubscriber
  autoload :Marshalling
  autoload :Migration
  autoload :Migrator, "active_record/migration"
  autoload :ModelSchema
  autoload :NestedAttributes
  autoload :NoTouching
  autoload :Normalization
  autoload :Persistence
  autoload :QueryCache
  autoload :QueryLogs
  autoload :Querying
  autoload :ReadonlyAttributes
  autoload :RecordInvalid, "active_record/validations"
  autoload :Reflection
  autoload :RuntimeRegistry
  autoload :Sanitization
  autoload :Schema
  autoload :SchemaDumper
  autoload :SchemaMigration
  autoload :Scoping
  autoload :SecurePassword
  autoload :SecureToken
  autoload :Serialization
  autoload :SignedId
  autoload :Store
  autoload :Suppressor
  autoload :TestDatabases
  autoload :TestFixtures, "active_record/fixtures"
  autoload :Timestamp
  autoload :TokenFor
  autoload :TouchLater
  autoload :Transactions
  autoload :Translation
  autoload :Validations

  eager_autoload do
    autoload :Aggregations
    autoload :AssociationRelation
    autoload :Associations
    autoload :AsynchronousQueriesTracker
    autoload :AttributeAssignment
    autoload :AttributeMethods
    autoload :AutosaveAssociation
    autoload :ConnectionAdapters
    autoload :DisableJoinsAssociationRelation
    autoload :FutureResult
    autoload :LegacyYamlAdapter
    autoload :Promise
    autoload :Relation
    autoload :Result
    autoload :StatementCache
    autoload :TableMetadata
    autoload :Transaction
    autoload :Type

    autoload_under "relation" do
      autoload :Batches
      autoload :Calculations
      autoload :Delegation
      autoload :FinderMethods
      autoload :PredicateBuilder
      autoload :QueryMethods
      autoload :SpawnMethods
    end
  end

  module Coders
    autoload :ColumnSerializer, "active_record/coders/column_serializer"
    autoload :JSON, "active_record/coders/json"
    autoload :YAMLColumn, "active_record/coders/yaml_column"
  end

  module AttributeMethods
    extend ActiveSupport::Autoload

    autoload :CompositePrimaryKey

    eager_autoload do
      autoload :BeforeTypeCast
      autoload :Dirty
      autoload :PrimaryKey
      autoload :Query
      autoload :Read
      autoload :Serialization
      autoload :TimeZoneConversion
      autoload :Write
    end
  end

  module Locking
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Optimistic
      autoload :Pessimistic
    end
  end

  module Scoping
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Default
      autoload :Named
    end
  end

  module Middleware
    extend ActiveSupport::Autoload

    autoload :DatabaseSelector
    autoload :ShardSelector
  end

  module Tasks
    extend ActiveSupport::Autoload

    autoload :DatabaseTasks
    autoload :MySQLDatabaseTasks,  "active_record/tasks/mysql_database_tasks"
    autoload :PostgreSQLDatabaseTasks, "active_record/tasks/postgresql_database_tasks"
    autoload :SQLiteDatabaseTasks, "active_record/tasks/sqlite_database_tasks"
  end

  singleton_class.attr_accessor :disable_prepared_statements
  self.disable_prepared_statements = false

  ##
  # :singleton-method: lazily_load_schema_cache
  # Lazily load the schema cache. This option will load the schema cache
  # when a connection is established rather than on boot.
  singleton_class.attr_accessor :lazily_load_schema_cache
  self.lazily_load_schema_cache = false

  ##
  # :singleton-method: schema_cache_ignored_tables
  # A list of tables or regex's to match tables to ignore when
  # dumping the schema cache. For example if this is set to +[/^_/]+
  # the schema cache will not dump tables named with an underscore.
  singleton_class.attr_accessor :schema_cache_ignored_tables
  self.schema_cache_ignored_tables = []

  # Checks to see if the +table_name+ is ignored by checking
  # against the +schema_cache_ignored_tables+ option.
  #
  #   ActiveRecord.schema_cache_ignored_table?(:developers)
  #
  def self.schema_cache_ignored_table?(table_name)
    ActiveRecord.schema_cache_ignored_tables.any? do |ignored|
      ignored === table_name
    end
  end

  singleton_class.attr_accessor :database_cli
  self.database_cli = { postgresql: "psql", mysql: %w[mysql mysql5], sqlite: "sqlite3" }

  singleton_class.attr_reader :default_timezone

  # Determines whether to use Time.utc (using :utc) or Time.local (using :local) when pulling
  # dates and times from the database. This is set to :utc by default.
  def self.default_timezone=(default_timezone)
    unless %i(local utc).include?(default_timezone)
      raise ArgumentError, "default_timezone must be either :utc (default) or :local."
    end

    @default_timezone = default_timezone
  end

  self.default_timezone = :utc

  ##
  # :singleton-method: db_warnings_action
  # The action to take when database query produces warning.
  # Must be one of :ignore, :log, :raise, :report, or a custom proc.
  # The default is :ignore.
  singleton_class.attr_reader :db_warnings_action

  def self.db_warnings_action=(action)
    @db_warnings_action =
      case action
      when :ignore
        nil
      when :log
        ->(warning) do
          warning_message = "[#{warning.class}] #{warning.message}"
          warning_message += " (#{warning.code})" if warning.code
          ActiveRecord::Base.logger.warn(warning_message)
        end
      when :raise
        ->(warning) { raise warning }
      when :report
        ->(warning) { Rails.error.report(warning, handled: true) }
      when Proc
        action
      else
        raise ArgumentError, "db_warnings_action must be one of :ignore, :log, :raise, :report, or a custom proc."
      end
  end

  self.db_warnings_action = :ignore

  ##
  # :singleton-method: db_warnings_ignore
  # Specify allowlist of database warnings.
  singleton_class.attr_accessor :db_warnings_ignore
  self.db_warnings_ignore = []

  singleton_class.attr_accessor :writing_role
  self.writing_role = :writing

  singleton_class.attr_accessor :reading_role
  self.reading_role = :reading

  ##
  # :singleton-method: async_query_executor
  # Sets the async_query_executor for an application. By default the thread pool executor
  # set to +nil+ which will not run queries in the background. Applications must configure
  # a thread pool executor to use this feature. Options are:
  #
  #   * nil - Does not initialize a thread pool executor. Any async calls will be
  #   run in the foreground.
  #   * :global_thread_pool - Initializes a single +Concurrent::ThreadPoolExecutor+
  #   that uses the +async_query_concurrency+ for the +max_threads+ value.
  #   * :multi_thread_pool - Initializes a +Concurrent::ThreadPoolExecutor+ for each
  #   database connection. The initializer values are defined in the configuration hash.
  singleton_class.attr_accessor :async_query_executor
  self.async_query_executor = nil

  def self.global_thread_pool_async_query_executor # :nodoc:
    concurrency = global_executor_concurrency || 4
    @global_thread_pool_async_query_executor ||= Concurrent::ThreadPoolExecutor.new(
      min_threads: 0,
      max_threads: concurrency,
      max_queue: concurrency * 4,
      fallback_policy: :caller_runs
    )
  end

  # Set the +global_executor_concurrency+. This configuration value can only be used
  # with the global thread pool async query executor.
  def self.global_executor_concurrency=(global_executor_concurrency)
    if self.async_query_executor.nil? || self.async_query_executor == :multi_thread_pool
      raise ArgumentError, "`global_executor_concurrency` cannot be set when the executor is nil or set to `:multi_thread_pool`. For multiple thread pools, please set the concurrency in your database configuration."
    end

    @global_executor_concurrency = global_executor_concurrency
  end

  def self.global_executor_concurrency # :nodoc:
    @global_executor_concurrency ||= nil
  end

  @permanent_connection_checkout = true
  singleton_class.attr_reader :permanent_connection_checkout

  # Defines whether +ActiveRecord::Base.connection+ is allowed, deprecated, or entirely disallowed.
  def self.permanent_connection_checkout=(value)
    unless [true, :deprecated, :disallowed].include?(value)
      raise ArgumentError, "permanent_connection_checkout must be one of: `true`, `:deprecated` or `:disallowed`"
    end
    @permanent_connection_checkout = value
  end

  singleton_class.attr_accessor :index_nested_attribute_errors
  self.index_nested_attribute_errors = false

  ##
  # :singleton-method: verbose_query_logs
  #
  # Specifies if the methods calling database queries should be logged below
  # their relevant queries. Defaults to false.
  singleton_class.attr_accessor :verbose_query_logs
  self.verbose_query_logs = false

  ##
  # :singleton-method: queues
  #
  # Specifies the names of the queues used by background jobs.
  singleton_class.attr_accessor :queues
  self.queues = {}

  singleton_class.attr_accessor :maintain_test_schema
  self.maintain_test_schema = nil

  singleton_class.attr_accessor :raise_on_assign_to_attr_readonly
  self.raise_on_assign_to_attr_readonly = false

  singleton_class.attr_accessor :belongs_to_required_validates_foreign_key
  self.belongs_to_required_validates_foreign_key = true

  singleton_class.attr_accessor :before_committed_on_all_records
  self.before_committed_on_all_records = false

  singleton_class.attr_accessor :run_after_transaction_callbacks_in_order_defined
  self.run_after_transaction_callbacks_in_order_defined = false

  singleton_class.attr_accessor :application_record_class
  self.application_record_class = nil

  ##
  # :singleton-method: action_on_strict_loading_violation
  # Set the application to log or raise when an association violates strict loading.
  # Defaults to :raise.
  singleton_class.attr_accessor :action_on_strict_loading_violation
  self.action_on_strict_loading_violation = :raise

  ##
  # :singleton-method: schema_format
  # Specifies the format to use when dumping the database schema with Rails'
  # Rakefile. If :sql, the schema is dumped as (potentially database-
  # specific) SQL statements. If :ruby, the schema is dumped as an
  # ActiveRecord::Schema file which can be loaded into any database that
  # supports migrations. Use :ruby if you want to have different database
  # adapters for, e.g., your development and test environments. This can be
  # overridden per-database in the database configuration.
  singleton_class.attr_accessor :schema_format
  self.schema_format = :ruby

  ##
  # :singleton-method: error_on_ignored_order
  # Specifies if an error should be raised if the query has an order being
  # ignored when doing batch queries. Useful in applications where the
  # scope being ignored is error-worthy, rather than a warning.
  singleton_class.attr_accessor :error_on_ignored_order
  self.error_on_ignored_order = false

  ##
  # :singleton-method: timestamped_migrations
  # Specify whether or not to use timestamps for migration versions
  singleton_class.attr_accessor :timestamped_migrations
  self.timestamped_migrations = true

  ##
  # :singleton-method: validate_migration_timestamps
  # Specify whether or not to validate migration timestamps. When set, an error
  # will be raised if a timestamp is more than a day ahead of the timestamp
  # associated with the current time. +timestamped_migrations+ must be set to true.
  singleton_class.attr_accessor :validate_migration_timestamps
  self.validate_migration_timestamps = false

  ##
  # :singleton-method: migration_strategy
  # Specify strategy to use for executing migrations.
  singleton_class.attr_accessor :migration_strategy
  self.migration_strategy = Migration::DefaultStrategy

  ##
  # :singleton-method: dump_schema_after_migration
  # Specify whether schema dump should happen at the end of the
  # bin/rails db:migrate command. This is true by default, which is useful for the
  # development environment. This should ideally be false in the production
  # environment where dumping schema is rarely needed.
  singleton_class.attr_accessor :dump_schema_after_migration
  self.dump_schema_after_migration = true

  ##
  # :singleton-method: dump_schemas
  # Specifies which database schemas to dump when calling db:schema:dump.
  # If the value is :schema_search_path (the default), any schemas listed in
  # schema_search_path are dumped. Use :all to dump all schemas regardless
  # of schema_search_path, or a string of comma separated schemas for a
  # custom list.
  singleton_class.attr_accessor :dump_schemas
  self.dump_schemas = :schema_search_path

  ##
  # :singleton-method: verify_foreign_keys_for_fixtures
  # If true, Rails will verify all foreign keys in the database after loading fixtures.
  # An error will be raised if there are any foreign key violations, indicating incorrectly
  # written fixtures.
  # Supported by PostgreSQL and SQLite.
  singleton_class.attr_accessor :verify_foreign_keys_for_fixtures
  self.verify_foreign_keys_for_fixtures = false

  singleton_class.attr_accessor :query_transformers
  self.query_transformers = []

  ##
  # :singleton-method: use_yaml_unsafe_load
  # Application configurable boolean that instructs the YAML Coder to use
  # an unsafe load if set to true.
  singleton_class.attr_accessor :use_yaml_unsafe_load
  self.use_yaml_unsafe_load = false

  ##
  # :singleton-method: raise_int_wider_than_64bit
  # Application configurable boolean that denotes whether or not to raise
  # an exception when the PostgreSQLAdapter is provided with an integer that
  # is wider than signed 64bit representation
  singleton_class.attr_accessor :raise_int_wider_than_64bit
  self.raise_int_wider_than_64bit = true

  ##
  # :singleton-method: yaml_column_permitted_classes
  # Application configurable array that provides additional permitted classes
  # to Psych safe_load in the YAML Coder
  singleton_class.attr_accessor :yaml_column_permitted_classes
  self.yaml_column_permitted_classes = [Symbol]

  ##
  # :singleton-method: generate_secure_token_on
  # Controls when to generate a value for <tt>has_secure_token</tt>
  # declarations. Defaults to <tt>:create</tt>.
  singleton_class.attr_accessor :generate_secure_token_on
  self.generate_secure_token_on = :create

  def self.marshalling_format_version
    Marshalling.format_version
  end

  def self.marshalling_format_version=(value)
    Marshalling.format_version = value
  end

  ##
  # :singleton-method: protocol_adapters
  # Provides a mapping between database protocols/DBMSs and the
  # underlying database adapter to be used. This is used only by the
  # <tt>DATABASE_URL</tt> environment variable.
  #
  # == Example
  #
  #   DATABASE_URL="mysql://myuser:mypass@localhost/somedatabase"
  #
  # The above URL specifies that MySQL is the desired protocol/DBMS, and the
  # application configuration can then decide which adapter to use. For this example
  # the default mapping is from <tt>mysql</tt> to <tt>mysql2</tt>, but <tt>:trilogy</tt>
  # is also supported.
  #
  #   ActiveRecord.protocol_adapters.mysql = "mysql2"
  #
  # The protocols names are arbitrary, and external database adapters can be
  # registered and set here.
  singleton_class.attr_accessor :protocol_adapters
  self.protocol_adapters = ActiveSupport::InheritableOptions.new(
    {
      sqlite: "sqlite3",
      mysql: "mysql2",
      postgres: "postgresql",
    }
  )

  def self.eager_load!
    super
    ActiveRecord::Locking.eager_load!
    ActiveRecord::Scoping.eager_load!
    ActiveRecord::Associations.eager_load!
    ActiveRecord::AttributeMethods.eager_load!
    ActiveRecord::ConnectionAdapters.eager_load!
    ActiveRecord::Encryption.eager_load!
  end

  # Explicitly closes all database connections in all pools.
  def self.disconnect_all!
    ConnectionAdapters::PoolConfig.disconnect_all!
  end

  # Registers a block to be called after all the current transactions have been
  # committed.
  #
  # If there is no currently open transaction, the block is called immediately.
  #
  # If there are multiple nested transactions, the block is called after the outermost one
  # has been committed,
  #
  # If any of the currently open transactions is rolled back, the block is never called.
  #
  # If multiple transactions are open across multiple databases, the block will be invoked
  # if and once all of them have been committed. But note that nesting transactions across
  # two distinct databases is a sharding anti-pattern that comes with a world of hurts.
  def self.after_all_transactions_commit(&block)
    open_transactions = all_open_transactions

    if open_transactions.empty?
      yield
    elsif open_transactions.size == 1
      open_transactions.first.after_commit(&block)
    else
      count = open_transactions.size
      callback = -> do
        count -= 1
        block.call if count.zero?
      end
      open_transactions.each do |t|
        t.after_commit(&callback)
      end
      open_transactions = nil # rubocop:disable Lint/UselessAssignment avoid holding it in the closure
    end
  end

  def self.all_open_transactions # :nodoc:
    open_transactions = []
    Base.connection_handler.each_connection_pool do |pool|
      if active_connection = pool.active_connection
        current_transaction = active_connection.current_transaction

        if current_transaction.open? && current_transaction.joinable? && !current_transaction.state.invalidated?
          open_transactions << current_transaction
        end
      end
    end
    open_transactions
  end
end

ActiveSupport.on_load(:active_record) do
  Arel::Table.engine = self
end

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path("active_record/locale/en.yml", __dir__)
end

YAML.load_tags["!ruby/object:ActiveRecord::AttributeSet"] = "ActiveModel::AttributeSet"
YAML.load_tags["!ruby/object:ActiveRecord::Attribute::FromDatabase"] = "ActiveModel::Attribute::FromDatabase"
YAML.load_tags["!ruby/object:ActiveRecord::LazyAttributeHash"] = "ActiveModel::LazyAttributeHash"
YAML.load_tags["!ruby/object:ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::MysqlString"] = "ActiveRecord::Type::String"
