# frozen_string_literal: true

require "cases/helper"
require "models/car"

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
      message = Car.where(name: "honda").explain
      assert_match(/^EXPLAIN for:/, message)
    end

    def test_collecting_queries_for_explain
      queries = ActiveRecord::Base.collecting_queries_for_explain do
        Car.where(name: "honda").to_a
      end

      sql, binds = queries[0]
      assert_match "SELECT", sql
      if binds.any?
        assert_equal 1, binds.length
        assert_equal "honda", binds.last.value
      else
        assert_match "honda", sql
      end
    end

    def test_exec_explain_with_no_binds
      sqls    = %w(foo bar)
      binds   = [[], []]
      queries = sqls.zip(binds)

      stub_explain_for_query_plans do
        expected = sqls.map { |sql| "EXPLAIN for: #{sql}\nquery plan #{sql}" }.join("\n")
        assert_equal expected, base.exec_explain(queries)
      end
    end

    def test_exec_explain_with_binds
      sqls    = %w(foo bar)
      binds   = [[bind_param("wadus", 1)], [bind_param("chaflan", 2)]]
      queries = sqls.zip(binds)

      stub_explain_for_query_plans(["query plan foo\n", "query plan bar\n"]) do
        expected = <<~SQL
          EXPLAIN for: #{sqls[0]} [["wadus", 1]]
          query plan foo

          EXPLAIN for: #{sqls[1]} [["chaflan", 2]]
          query plan bar
        SQL
        assert_equal expected, base.exec_explain(queries)
      end
    end

    private
      def stub_explain_for_query_plans(query_plans = ["query plan foo", "query plan bar"], &block)
        explain_called = 0

        connection.stub(:explain, proc { explain_called += 1; query_plans[explain_called - 1] }, &block)
      end

      def bind_param(name, value)
        ActiveRecord::Relation::QueryAttribute.new(name, value, ActiveRecord::Type::Value.new)
      end
  end
end
