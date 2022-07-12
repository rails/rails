# frozen_string_literal: true

#--
# Copyright (c) 2004-2022 David Heinemeier Hansson
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
require "active_model/attribute_set"
require "active_record/errors"

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
  autoload :Inheritance
  autoload :Integration
  autoload :InternalMetadata
  autoload :Migration
  autoload :Migrator, "active_record/migration"
  autoload :ModelSchema
  autoload :NestedAttributes
  autoload :NoTouching
  autoload :Persistence
  autoload :QueryCache
  autoload :Querying
  autoload :QueryLogs
  autoload :ReadonlyAttributes
  autoload :RecordInvalid, "active_record/validations"
  autoload :Reflection
  autoload :RuntimeRegistry
  autoload :Sanitization
  autoload :Schema
  autoload :SchemaDumper
  autoload :SchemaMigration
  autoload :Scoping
  autoload :SecureToken
  autoload :Serialization
  autoload :SignedId
  autoload :Store
  autoload :Suppressor
  autoload :TestDatabases
  autoload :TestFixtures, "active_record/fixtures"
  autoload :Timestamp
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
    autoload :NullRelation
    autoload :Relation
    autoload :Result
    autoload :StatementCache
    autoload :TableMetadata
    autoload :Type

    autoload_under "relation" do
      autoload :QueryMethods
      autoload :FinderMethods
      autoload :Calculations
      autoload :PredicateBuilder
      autoload :SpawnMethods
      autoload :Batches
      autoload :Delegation
    end
  end

  module Coders
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

  singleton_class.attr_accessor :legacy_connection_handling
  self.legacy_connection_handling = true

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

  singleton_class.attr_accessor :writing_role
  self.writing_role = :writing

  singleton_class.attr_accessor :reading_role
  self.reading_role = :reading

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

  ##
  # :singleton-method:
  # Show a warning when Rails couldn't parse your database.yml
  # for multiple databases.
  singleton_class.attr_accessor :suppress_multiple_database_warning
  self.suppress_multiple_database_warning = false

  ##
  # :singleton-method:
  # If true, Rails will verify all foreign keys in the database after loading fixtures.
  # An error will be raised if there are any foreign key violations, indicating incorrectly
  # written fixtures.
  # Supported by PostgreSQL and SQLite.
  singleton_class.attr_accessor :verify_foreign_keys_for_fixtures
  self.verify_foreign_keys_for_fixtures = false

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
  # Application configurable array that provides additional permitted classes
  # to Psych safe_load in the YAML Coder
  singleton_class.attr_accessor :yaml_column_permitted_classes
  self.yaml_column_permitted_classes = []

  def self.eager_load!
    super
    ActiveRecord::Locking.eager_load!
    ActiveRecord::Scoping.eager_load!
    ActiveRecord::Associations.eager_load!
    ActiveRecord::AttributeMethods.eager_load!
    ActiveRecord::ConnectionAdapters.eager_load!
    ActiveRecord::Encryption.eager_load!
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
