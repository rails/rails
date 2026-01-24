# frozen_string_literal: true

require "cases/helper"
require "models/car"

if ActiveRecord::Base.lease_connection.supports_explain?
  class ExplainTest < ActiveRecord::TestCase
    fixtures :cars

    def base
      ActiveRecord::Base
    end

    def lease_connection
      base.lease_connection
    end

    def test_relation_explain
      message = Car.where(name: "honda").explain.inspect
      assert_match(/^EXPLAIN/, message)
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

    def test_relation_explain_with_average
      expected_query = capture_sql {
        Car.average(:id)
      }.first
      message = Car.all.explain.average(:id)
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query, message)
    end

    def test_relation_explain_with_count
      expected_query = capture_sql {
        Car.count
      }.first
      message = Car.all.explain.count
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query, message)
    end

    def test_relation_explain_with_count_and_argument
      expected_query = capture_sql {
        Car.count(:id)
      }.first
      message = Car.all.explain.count(:id)
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query, message)
    end

    def test_relation_explain_with_minimum
      expected_query = capture_sql {
        Car.minimum(:id)
      }.first
      message = Car.all.explain.minimum(:id)
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query, message)
    end

    def test_relation_explain_with_maximum
      expected_query = capture_sql {
        Car.maximum(:id)
      }.first
      message = Car.all.explain.maximum(:id)
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query, message)
    end

    def test_relation_explain_with_sum
      expected_query = capture_sql {
        Car.sum(:id)
      }.first
      message = Car.all.explain.sum(:id)
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query, message)
    end

    def test_relation_explain_with_first
      expected_query = capture_sql {
        Car.all.first
      }.first
      message = Car.all.explain.first
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query.sub(/LIMIT.*/, ""), message)
    end

    def test_relation_explain_with_last
      expected_query = capture_sql {
        Car.all.last
      }.first
      message = Car.all.explain.last
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query.sub(/LIMIT.*/, ""), message)
    end

    def test_relation_explain_with_pluck
      expected_query = capture_sql {
        Car.all.pluck
      }.first
      message = Car.all.explain.pluck
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query, message)
    end

    def test_relation_explain_with_pluck_with_args
      expected_query = capture_sql {
        Car.all.pluck(:id, :name)
      }.first
      message = Car.all.explain.pluck(:id, :name)
      assert_match(/^EXPLAIN/, message)
      assert_match(expected_query, message)
    end

    def test_exec_explain_with_no_binds
      sqls    = %w(foo bar)
      binds   = [[], []]
      queries = sqls.zip(binds)

      stub_explain_for_query_plans do
        expected = sqls.map { |sql| "#{expected_explain_clause} #{sql}\nquery plan #{sql}" }.join("\n")
        assert_equal expected, base.exec_explain(queries)
      end
    end

    def test_exec_explain_with_binds
      sqls    = %w(foo bar)
      binds   = [[bind_param("wadus", 1)], [bind_param("chaflan", 2)]]
      queries = sqls.zip(binds)

      stub_explain_for_query_plans(["query plan foo\n", "query plan bar\n"]) do
        expected = <<~SQL
          #{expected_explain_clause} #{sqls[0]} [["wadus", 1]]
          query plan foo

          #{expected_explain_clause} #{sqls[1]} [["chaflan", 2]]
          query plan bar
        SQL
        assert_equal expected, base.exec_explain(queries)
      end
    end

    private
      def stub_explain_for_query_plans(query_plans = ["query plan foo", "query plan bar"])
        explain_called = 0

        # Minitest's `stub` method is unable to correctly replicate method arguments
        # signature, so we need to do a manual stubbing in this case.
        metaclass = lease_connection.singleton_class
        explain_method = metaclass.instance_method(:explain)
        metaclass.define_method(:explain) do |_arel, _binds = [], _options = {}|
          explain_called += 1
          query_plans[explain_called - 1]
        end
        yield
      ensure
        if metaclass
          metaclass.undef_method(:explain)
          metaclass.define_method(:explain, explain_method)
        end
      end

      def bind_param(name, value)
        ActiveRecord::Relation::QueryAttribute.new(name, value, ActiveRecord::Type::Value.new)
      end

      def expected_explain_clause
        if lease_connection.respond_to?(:build_explain_clause)
          lease_connection.build_explain_clause
        else
          "EXPLAIN for:"
        end
      end
  end
end
