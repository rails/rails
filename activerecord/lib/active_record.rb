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
require "active_model"
require "arel"
require "yaml"

require "active_record/version"
require "active_record/deprecator"
require "active_model/attribute_set"
require "active_record/errors"

# :include: activerecord/README.rdoc
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

  # Lazily load the schema cache. This option will load the schema cache
  # when a connection is established rather than on boot. If set,
  # +config.active_record.use_schema_cache_dump+ will be set to false.
  singleton_class.attr_accessor :lazily_load_schema_cache
  self.lazily_load_schema_cache = false

  # A list of tables or regex's to match tables to ignore when
  # dumping the schema cache. For example if this is set to +[/^_/]+
  # the schema cache will not dump tables named with an underscore.
  singleton_class.attr_accessor :schema_cache_ignored_tables
  self.schema_cache_ignored_tables = []

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

  # Specify allowlist of database warnings.
  singleton_class.attr_accessor :db_warnings_ignore
  self.db_warnings_ignore = []

  singleton_class.attr_accessor :writing_role
  self.writing_role = :writing

  singleton_class.attr_accessor :reading_role
  self.reading_role = :reading

  def self.legacy_connection_handling=(_)
    raise ArgumentError, <<~MSG.squish
      The `legacy_connection_handling` setter was deprecated in 7.0 and removed in 7.1,
      but is still defined in your configuration. Please remove this call as it no longer
      has any effect."
    MSG
  end

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
      raise ArgumentError, "`global_executor_concurrency` cannot be set when using the executor is nil or set to multi_thead_pool. For multiple thread pools, please set the concurrency in your database configuration."
    end

    @global_executor_concurrency = global_executor_concurrency
  end

  def self.global_executor_concurrency # :nodoc:
    @global_executor_concurrency ||= nil
  end

  singleton_class.attr_accessor :index_nested_attribute_errors
  self.index_nested_attribute_errors = false

  ##
  # :singleton-method:
  #
  # Specifies if the methods calling database queries should be logged below
  # their relevant queries. Defaults to false.
  singleton_class.attr_accessor :verbose_query_logs
  self.verbose_query_logs = false

  ##
  # :singleton-method:
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

  singleton_class.attr_accessor :commit_transaction_on_non_local_return
  self.commit_transaction_on_non_local_return = false

  ##
  # :singleton-method:
  # Specify a threshold for the size of query result sets. If the number of
  # records in the set exceeds the threshold, a warning is logged. This can
  # be used to identify queries which load thousands of records and
  # potentially cause memory bloat.
  singleton_class.attr_accessor :warn_on_records_fetched_greater_than
  self.warn_on_records_fetched_greater_than = false

  singleton_class.attr_accessor :application_record_class
  self.application_record_class = nil

  ##
  # :singleton-method:
  # Set the application to log or raise when an association violates strict loading.
  # Defaults to :raise.
  singleton_class.attr_accessor :action_on_strict_loading_violation
  self.action_on_strict_loading_violation = :raise

  ##
  # :singleton-method:
  # Specifies the format to use when dumping the database schema with Rails'
  # Rakefile. If :sql, the schema is dumped as (potentially database-
  # specific) SQL statements. If :ruby, the schema is dumped as an
  # ActiveRecord::Schema file which can be loaded into any database that
  # supports migrations. Use :ruby if you want to have different database
  # adapters for, e.g., your development and test environments.
  singleton_class.attr_accessor :schema_format
  self.schema_format = :ruby

  ##
  # :singleton-method:
  # Specifies if an error should be raised if the query has an order being
  # ignored when doing batch queries. Useful in applications where the
  # scope being ignored is error-worthy, rather than a warning.
  singleton_class.attr_accessor :error_on_ignored_order
  self.error_on_ignored_order = false

  ##
  # :singleton-method:
  # Specify whether or not to use timestamps for migration versions
  singleton_class.attr_accessor :timestamped_migrations
  self.timestamped_migrations = true

  ##
  # :singleton-method:
  # Specify strategy to use for executing migrations.
  singleton_class.attr_accessor :migration_strategy
  self.migration_strategy = Migration::DefaultStrategy

  ##
  # :singleton-method:
  # Specify whether schema dump should happen at the end of the
  # bin/rails db:migrate command. This is true by default, which is useful for the
  # development environment. This should ideally be false in the production
  # environment where dumping schema is rarely needed.
  singleton_class.attr_accessor :dump_schema_after_migration
  self.dump_schema_after_migration = true

  ##
  # :singleton-method:
  # Specifies which database schemas to dump when calling db:schema:dump.
  # If the value is :schema_search_path (the default), any schemas listed in
  # schema_search_path are dumped. Use :all to dump all schemas regardless
  # of schema_search_path, or a string of comma separated schemas for a
  # custom list.
  singleton_class.attr_accessor :dump_schemas
  self.dump_schemas = :schema_search_path

  def self.suppress_multiple_database_warning
    ActiveRecord.deprecator.warn(<<-MSG.squish)
      config.active_record.suppress_multiple_database_warning is deprecated and will be removed in Rails 7.2.
      It no longer has any effect and should be removed from the configuration file.
    MSG
  end

  def self.suppress_multiple_database_warning=(value)
    ActiveRecord.deprecator.warn(<<-MSG.squish)
      config.active_record.suppress_multiple_database_warning= is deprecated and will be removed in Rails 7.2.
      It no longer has any effect and should be removed from the configuration file.
    MSG
  end

  ##
  # :singleton-method:
  # If true, Rails will verify all foreign keys in the database after loading fixtures.
  # An error will be raised if there are any foreign key violations, indicating incorrectly
  # written fixtures.
  # Supported by PostgreSQL and SQLite.
  singleton_class.attr_accessor :verify_foreign_keys_for_fixtures
  self.verify_foreign_keys_for_fixtures = false

  ##
  # :singleton-method:
  # If true, Rails will continue allowing plural association names in where clauses on singular associations
  # This behavior will be removed in Rails 7.2.
  singleton_class.attr_accessor :allow_deprecated_singular_associations_name
  self.allow_deprecated_singular_associations_name = true

  singleton_class.attr_accessor :query_transformers
  self.query_transformers = []

  ##
  # :singleton-method:
  # Application configurable boolean that instructs the YAML Coder to use
  # an unsafe load if set to true.
  singleton_class.attr_accessor :use_yaml_unsafe_load
  self.use_yaml_unsafe_load = false

  ##
  # :singleton-method:
  # Application configurable boolean that denotes whether or not to raise
  # an exception when the PostgreSQLAdapter is provided with an integer that
  # is wider than signed 64bit representation
  singleton_class.attr_accessor :raise_int_wider_than_64bit
  self.raise_int_wider_than_64bit = true

  ##
  # :singleton-method:
  # Application configurable array that provides additional permitted classes
  # to Psych safe_load in the YAML Coder
  singleton_class.attr_accessor :yaml_column_permitted_classes
  self.yaml_column_permitted_classes = [Symbol]

  ##
  # :singleton-method:
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
