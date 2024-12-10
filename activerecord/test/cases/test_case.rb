# frozen_string_literal: true

require "active_support/testing/strict_warnings"
require "active_support"
require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"
require "active_support/testing/stream"
require "active_record/testing/query_assertions"
require "active_record/fixtures"

require "cases/validations_repair_helper"
require_relative "../support/config"
require_relative "../support/connection"
require_relative "../support/adapter_helper"
require_relative "../support/load_schema_helper"

module ActiveRecord
  # = Active Record Test Case
  #
  # Defines some test assertions to test against SQL queries.
  class TestCase < ActiveSupport::TestCase # :nodoc:
    include ActiveSupport::Testing::MethodCallAssertions
    include ActiveSupport::Testing::Stream
    include ActiveRecord::Assertions::QueryAssertions
    include ActiveRecord::TestFixtures
    include ActiveRecord::ValidationsRepairHelper
    include AdapterHelper
    extend AdapterHelper
    include LoadSchemaHelper
    extend LoadSchemaHelper

    self.fixture_paths = [FIXTURES_ROOT]
    self.use_instantiated_fixtures = false
    self.use_transactional_tests = true

    def after_teardown
      super
      check_connection_leaks
    end

    def check_connection_leaks
      return if in_memory_db?

      # Make sure tests didn't leave a connection owned by some background thread
      # which could lead to some slow wait in a subsequent thread.
      leaked_conn = []
      ActiveRecord::Base.connection_handler.each_connection_pool do |pool|
        # Ensure all in flights tasks are completed.
        # Otherwise they may still hold a connection.
        if pool.async_executor
          if pool.async_executor.scheduled_task_count != pool.async_executor.completed_task_count
            pool.connections.each do |conn|
              if conn.in_use? && conn.owner != Fiber.current && conn.owner != Thread.current
                if conn.owner.respond_to?(:join)
                  conn.owner&.join(0.5)
                end
              end
            end
          end
        end

        pool.reap
        pool.connections.each do |conn|
          if conn.in_use?
            if conn.owner != Fiber.current && conn.owner != Thread.current
              leaked_conn << [conn.owner, conn.owner.backtrace]
              conn.owner&.kill
            end
            conn.steal!
            pool.checkin(conn)
          end
        end
      end

      if leaked_conn.size > 0
        puts "Found #{leaked_conn.size} leaked connections"
        leaked_conn.each do |owner, backtrace|
          puts "owner: #{owner}"
          puts "backtrace:\n#{backtrace}"
          puts
        end
        raise "Found #{leaked_conn.size} leaked connection after #{self.class.name}##{name}"
      end
    end

    def create_fixtures(*fixture_set_names)
      ActiveRecord::FixtureSet.create_fixtures(ActiveRecord::TestCase.fixture_paths, fixture_set_names, fixture_class_names)
    end

    def capture_sql(include_schema: false)
      counter = SQLCounter.new
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        yield
        if include_schema
          counter.log_all
        else
          counter.log
        end
      end
    end

    def capture_sql_and_binds
      counter = SQLCounter.new
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        yield
        counter.log_full
      end
    end

    # Redefine existing assertion method to explicitly not materialize transactions.
    def assert_queries_match(match, count: nil, include_schema: false, &block)
      counter = SQLCounter.new
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        result = _assert_nothing_raised_or_warn("assert_queries_match", &block)
        queries = include_schema ? counter.log_all : counter.log
        matched_queries = queries.select { |query| match === query }

        if count
          assert_equal count, matched_queries.size, "#{matched_queries.size} instead of #{count} queries were executed.#{queries.empty? ? '' : "\nQueries:\n#{queries.join("\n")}"}"
        else
          assert_operator matched_queries.size, :>=, 1, "1 or more queries expected, but none were executed.#{queries.empty? ? '' : "\nQueries:\n#{queries.join("\n")}"}"
        end

        result
      end
    end

    def assert_column(model, column_name, msg = nil)
      model.reset_column_information
      assert_includes model.column_names, column_name.to_s, msg
    end

    def assert_no_column(model, column_name, msg = nil)
      model.reset_column_information
      assert_not_includes model.column_names, column_name.to_s, msg
    end

    def with_has_many_inversing(model = ActiveRecord::Base)
      old = model.has_many_inversing
      model.has_many_inversing = true
      yield
    ensure
      model.has_many_inversing = old
    end

    def with_automatic_scope_inversing(*reflections)
      old = reflections.map { |reflection| reflection.klass.automatic_scope_inversing }

      reflections.each do |reflection|
        reflection.klass.automatic_scope_inversing = true
        reflection.remove_instance_variable(:@inverse_name) if reflection.instance_variable_defined?(:@inverse_name)
        reflection.remove_instance_variable(:@inverse_of) if reflection.instance_variable_defined?(:@inverse_of)
      end

      yield
    ensure
      reflections.each_with_index do |reflection, i|
        reflection.klass.automatic_scope_inversing = old[i]
        reflection.remove_instance_variable(:@inverse_name) if reflection.instance_variable_defined?(:@inverse_name)
        reflection.remove_instance_variable(:@inverse_of) if reflection.instance_variable_defined?(:@inverse_of)
      end
    end

    def with_db_warnings_action(action, warnings_to_ignore = [])
      original_db_warnings_ignore = ActiveRecord.db_warnings_ignore

      ActiveRecord.db_warnings_action = action
      ActiveRecord.db_warnings_ignore = warnings_to_ignore

      ActiveRecord::Base.lease_connection.disconnect! # Disconnect from the db so that we reconfigure the connection

      yield
    ensure
      ActiveRecord.db_warnings_action = @original_db_warnings_action
      ActiveRecord.db_warnings_ignore = original_db_warnings_ignore
      ActiveRecord::Base.lease_connection.disconnect!
    end

    def reset_callbacks(klass, kind)
      old_callbacks = {}
      old_callbacks[klass] = klass.send("_#{kind}_callbacks").dup
      klass.subclasses.each do |subclass|
        old_callbacks[subclass] = subclass.send("_#{kind}_callbacks").dup
      end
      yield
    ensure
      klass.send("_#{kind}_callbacks=", old_callbacks[klass])
      klass.subclasses.each do |subclass|
        subclass.send("_#{kind}_callbacks=", old_callbacks[subclass])
      end
    end

    def with_postgresql_datetime_type(type)
      adapter = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      adapter.remove_instance_variable(:@native_database_types) if adapter.instance_variable_defined?(:@native_database_types)
      datetime_type_was = adapter.datetime_type
      adapter.datetime_type = type
      yield
    ensure
      adapter = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      adapter.datetime_type = datetime_type_was
      adapter.remove_instance_variable(:@native_database_types) if adapter.instance_variable_defined?(:@native_database_types)
    end

    def with_env_tz(new_tz = "US/Eastern")
      old_tz, ENV["TZ"] = ENV["TZ"], new_tz
      yield
    ensure
      old_tz ? ENV["TZ"] = old_tz : ENV.delete("TZ")
    end

    def with_timezone_config(cfg)
      verify_default_timezone_config

      old_default_zone = ActiveRecord.default_timezone
      old_awareness = ActiveRecord::Base.time_zone_aware_attributes
      old_aware_types = ActiveRecord::Base.time_zone_aware_types
      old_zone = Time.zone

      if cfg.has_key?(:default)
        ActiveRecord.default_timezone = cfg[:default]
      end
      if cfg.has_key?(:aware_attributes)
        ActiveRecord::Base.time_zone_aware_attributes = cfg[:aware_attributes]
      end
      if cfg.has_key?(:aware_types)
        ActiveRecord::Base.time_zone_aware_types = cfg[:aware_types]
      end
      if cfg.has_key?(:zone)
        Time.zone = cfg[:zone]
      end
      yield
    ensure
      ActiveRecord.default_timezone = old_default_zone
      ActiveRecord::Base.time_zone_aware_attributes = old_awareness
      ActiveRecord::Base.time_zone_aware_types = old_aware_types
      Time.zone = old_zone
    end

    # This method makes sure that tests don't leak global state related to time zones.
    EXPECTED_ZONE = nil
    EXPECTED_DEFAULT_TIMEZONE = :utc
    EXPECTED_AWARE_TYPES = [:datetime, :time]
    EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES = false
    def verify_default_timezone_config
      if Time.zone != EXPECTED_ZONE
        $stderr.puts <<-MSG
    \n#{self}
        Global state `Time.zone` was leaked.
          Expected: #{EXPECTED_ZONE}
          Got: #{Time.zone}
        MSG
      end
      if ActiveRecord.default_timezone != EXPECTED_DEFAULT_TIMEZONE
        $stderr.puts <<-MSG
    \n#{self}
        Global state `ActiveRecord.default_timezone` was leaked.
          Expected: #{EXPECTED_DEFAULT_TIMEZONE}
          Got: #{ActiveRecord.default_timezone}
        MSG
      end
      if ActiveRecord::Base.time_zone_aware_attributes != EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES
        $stderr.puts <<-MSG
    \n#{self}
        Global state `ActiveRecord::Base.time_zone_aware_attributes` was leaked.
          Expected: #{EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES}
          Got: #{ActiveRecord::Base.time_zone_aware_attributes}
        MSG
      end
      if ActiveRecord::Base.time_zone_aware_types != EXPECTED_AWARE_TYPES
        $stderr.puts <<-MSG
    \n#{self}
        Global state `ActiveRecord::Base.time_zone_aware_types` was leaked.
          Expected: #{EXPECTED_AWARE_TYPES}
          Got: #{ActiveRecord::Base.time_zone_aware_types}
        MSG
      end
    end

    def clean_up_connection_handler
      handler = ActiveRecord::Base.connection_handler
      handler.instance_variable_get(:@connection_name_to_pool_manager).each do |owner, pool_manager|
        pool_manager.role_names.each do |role_name|
          next if role_name == ActiveRecord::Base.default_role &&
                  # TODO: Remove this helper when `remove_connection` for different shards is fixed.
                  # See https://github.com/rails/rails/pull/49382.
                  ["ActiveRecord::Base", "ARUnit2Model", "Contact", "ContactSti"].include?(owner)
          pool_manager.remove_role(role_name)
        end
      end
    end

    def quote_table_name(name)
      ActiveRecord::Base.adapter_class.quote_table_name(name)
    end

    # Connect to the database
    ARTest.connect
    # Load database schema
    load_schema
  end

  class PostgreSQLTestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:PostgreSQLAdapter)
    end
  end

  class AbstractMysqlTestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    end
  end

  class Mysql2TestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:Mysql2Adapter)
    end
  end

  class TrilogyTestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:TrilogyAdapter)
    end
  end

  class SQLite3TestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:SQLite3Adapter)
    end
  end
end
