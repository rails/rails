# frozen_string_literal: true

require "active_support/testing/strict_warnings"
require "active_support"
require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"
require "active_support/testing/stream"
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
    include ActiveRecord::TestFixtures
    include ActiveRecord::ValidationsRepairHelper
    include AdapterHelper
    extend AdapterHelper
    include LoadSchemaHelper
    extend LoadSchemaHelper

    self.fixture_paths = [FIXTURES_ROOT]
    self.use_instantiated_fixtures = false
    self.use_transactional_tests = true

    def create_fixtures(*fixture_set_names, &block)
      ActiveRecord::FixtureSet.create_fixtures(ActiveRecord::TestCase.fixture_paths, fixture_set_names, fixture_class_names, &block)
    end

    def teardown
      SQLCounter.clear_log
    end

    def capture_sql
      ActiveRecord::Base.connection.materialize_transactions
      SQLCounter.clear_log
      yield
      SQLCounter.log.dup
    end

    def assert_sql(*patterns_to_match, &block)
      _assert_nothing_raised_or_warn("assert_sql") { capture_sql(&block) }

      failed_patterns = []
      patterns_to_match.each do |pattern|
        failed_patterns << pattern unless SQLCounter.log_all.any? { |sql| pattern === sql }
      end
      assert_predicate failed_patterns, :empty?, "Query pattern(s) #{failed_patterns.map(&:inspect).join(', ')} not found.#{SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{SQLCounter.log.join("\n")}"}"
    end

    def assert_queries(num = 1, options = {}, &block)
      ignore_none = options.fetch(:ignore_none) { num == :any }
      ActiveRecord::Base.connection.materialize_transactions
      SQLCounter.clear_log
      x = _assert_nothing_raised_or_warn("assert_queries", &block)
      the_log = ignore_none ? SQLCounter.log_all : SQLCounter.log
      if num == :any
        assert_operator the_log.size, :>=, 1, "1 or more queries expected, but none were executed."
      else
        mesg = "#{the_log.size} instead of #{num} queries were executed.#{the_log.size == 0 ? '' : "\nQueries:\n#{the_log.join("\n")}"}"
        assert_equal num, the_log.size, mesg
      end
      x
    end

    def assert_no_queries(options = {}, &block)
      options.reverse_merge! ignore_none: true
      assert_queries(0, options, &block)
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
      if model != ActiveRecord::Base && !old
        model.singleton_class.remove_method(:has_many_inversing) # reset the class_attribute
      end
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

      ActiveRecord::Base.connection.disconnect! # Disconnect from the db so that we reconfigure the connection

      yield
    ensure
      ActiveRecord.db_warnings_action = @original_db_warnings_action
      ActiveRecord.db_warnings_ignore = original_db_warnings_ignore
      ActiveRecord::Base.connection.disconnect!
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
      super if current_adapter?(:Mysql2Adapter) || current_adapter?(:TrilogyAdapter)
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

  class SQLCounter
    class << self
      attr_accessor :ignored_sql, :log, :log_all
      def clear_log; self.log = []; self.log_all = []; end
    end

    clear_log

    def call(name, start, finish, message_id, values)
      return if values[:cached]

      sql = values[:sql]
      self.class.log_all << sql
      self.class.log << sql unless ["SCHEMA", "TRANSACTION"].include? values[:name]
    end
  end

  ActiveSupport::Notifications.subscribe("sql.active_record", SQLCounter.new)
end
