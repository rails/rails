# frozen_string_literal: true

require "active_support"
require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"
require "active_support/testing/stream"
require "active_record/fixtures"

require "cases/validations_repair_helper"

module ActiveRecord
  # = Active Record Test Case
  #
  # Defines some test assertions to test against SQL queries.
  class TestCase < ActiveSupport::TestCase #:nodoc:
    include ActiveSupport::Testing::MethodCallAssertions
    include ActiveSupport::Testing::Stream
    include ActiveRecord::TestFixtures
    include ActiveRecord::ValidationsRepairHelper

    self.fixture_path = FIXTURES_ROOT
    self.use_instantiated_fixtures = false
    self.use_transactional_tests = true

    def create_fixtures(*fixture_set_names, &block)
      ActiveRecord::FixtureSet.create_fixtures(ActiveRecord::TestCase.fixture_path, fixture_set_names, fixture_class_names, &block)
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

    def assert_sql(*patterns_to_match)
      capture_sql { yield }
    ensure
      failed_patterns = []
      patterns_to_match.each do |pattern|
        failed_patterns << pattern unless SQLCounter.log_all.any? { |sql| pattern === sql }
      end
      assert failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map(&:inspect).join(', ')} not found.#{SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{SQLCounter.log.join("\n")}"}"
    end

    def assert_queries(num = 1, options = {})
      ignore_none = options.fetch(:ignore_none) { num == :any }
      ActiveRecord::Base.connection.materialize_transactions
      SQLCounter.clear_log
      x = yield
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
      assert has_column?(model, column_name), msg
    end

    def assert_no_column(model, column_name, msg = nil)
      assert_not has_column?(model, column_name), msg
    end

    def has_column?(model, column_name)
      model.reset_column_information
      model.column_names.include?(column_name.to_s)
    end

    def with_has_many_inversing
      old = ActiveRecord::Base.has_many_inversing
      ActiveRecord::Base.has_many_inversing = true
      yield
    ensure
      ActiveRecord::Base.has_many_inversing = old
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
  end

  class PostgreSQLTestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:PostgreSQLAdapter)
    end
  end

  class Mysql2TestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:Mysql2Adapter)
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
