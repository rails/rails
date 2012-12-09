require 'cases/helper'
require 'models/car'
require 'active_support/core_ext/string/strip'

if ActiveRecord::Base.connection.supports_explain?
  class ExplainTest < ActiveRecord::TestCase
    fixtures :cars

    def base
      ActiveRecord::Base
    end

    def connection
      base.connection
    end

    def test_logging_query_plan_with_logger
      base.logger.expects(:warn).with do |message|
        message.starts_with?('EXPLAIN for:')
      end

      with_threshold(0) do
        Car.where(:name => 'honda').to_a
      end
    end

    def test_logging_query_plan_without_logger
      original = base.logger
      base.logger = nil

      class << base.logger
        def warn; raise "Should not be called" end
      end

      with_threshold(0) do
        car = Car.where(:name => 'honda').first
        assert_equal 'honda', car.name
      end
    ensure
      base.logger = original
    end

    def test_collect_queries_for_explain
      base.auto_explain_threshold_in_seconds = nil
      queries = Thread.current[:available_queries_for_explain] = []

      with_threshold(0) do
        Car.where(:name => 'honda').to_a
      end

      sql, binds = queries[0]
      assert_match "SELECT", sql
      assert_match "honda", sql
      assert_equal [], binds
    ensure
      Thread.current[:available_queries_for_explain] = nil
    end

    def test_collecting_queries_for_explain
      result, queries = ActiveRecord::Base.collecting_queries_for_explain do
        Car.where(:name => 'honda').to_a
      end

      sql, binds = queries[0]
      assert_match "SELECT", sql
      assert_match "honda", sql
      assert_equal [], binds
      assert_equal [cars(:honda)], result
    end

    def test_logging_query_plan_when_counting_by_sql
      base.logger.expects(:warn).with do |message|
        message.starts_with?('EXPLAIN for:')
      end

      with_threshold(0) do
        Car.count_by_sql "SELECT COUNT(*) FROM cars WHERE name = 'honda'"
      end
    end

    def test_exec_explain_with_no_binds
      sqls    = %w(foo bar)
      binds   = [[], []]
      queries = sqls.zip(binds)

      connection.stubs(:explain).returns('query plan foo', 'query plan bar')
      expected = sqls.map {|sql| "EXPLAIN for: #{sql}\nquery plan #{sql}"}.join("\n")
      assert_equal expected, base.exec_explain(queries)
    end

    def test_exec_explain_with_binds
      cols = [Object.new, Object.new]
      cols[0].expects(:name).returns('wadus')
      cols[1].expects(:name).returns('chaflan')

      sqls    = %w(foo bar)
      binds   = [[[cols[0], 1]], [[cols[1], 2]]]
      queries = sqls.zip(binds)

      connection.stubs(:explain).returns("query plan foo\n", "query plan bar\n")
      expected = <<-SQL.strip_heredoc
        EXPLAIN for: #{sqls[0]} [["wadus", 1]]
        query plan foo

        EXPLAIN for: #{sqls[1]} [["chaflan", 2]]
        query plan bar
      SQL
      assert_equal expected, base.exec_explain(queries)
    end

    def test_unsupported_connection_adapter
      connection.stubs(:supports_explain?).returns(false)

      base.logger.expects(:warn).never

      with_threshold(0) do
        Car.where(:name => 'honda').to_a
      end
    end

    def test_silence_auto_explain
      base.expects(:collecting_sqls_for_explain).never
      base.logger.expects(:warn).never
      base.silence_auto_explain do
        with_threshold(0) { Car.all }
      end
    end

    def with_threshold(threshold)
      current_threshold = base.auto_explain_threshold_in_seconds
      base.auto_explain_threshold_in_seconds = threshold
      yield
    ensure
      base.auto_explain_threshold_in_seconds = current_threshold
    end
  end
end
