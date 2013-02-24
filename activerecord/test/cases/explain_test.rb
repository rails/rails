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

    def test_relation_explain
      message = Car.where(:name => 'honda').explain
      assert_match(/^EXPLAIN for:/, message)
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

      Car.where(:name => 'honda').to_a
    end

  end
end
