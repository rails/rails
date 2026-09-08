# frozen_string_literal: true

require_relative "../helper"
require "yaml"

module Arel
  module Nodes
    class SqlLiteralTest < Arel::Test
      setup do
        @visitor = Visitors::ToSql.new(Table.engine.lease_connection)
      end

      test "sql makes a sql literal node" do
        sql = Arel.sql "foo"
        assert_kind_of Arel::Nodes::SqlLiteral, sql
      end

      test "count makes a count node" do
        node = SqlLiteral.new("*").count
        assert_like %{ COUNT(*) }, compile(node)
      end

      test "count makes a distinct node" do
        node = SqlLiteral.new("*").count true
        assert_like %{ COUNT(DISTINCT *) }, compile(node)
      end

      test "equality makes an equality node" do
        node = SqlLiteral.new("foo").eq(1)
        assert_like %{ foo = 1 }, compile(node)
      end

      test "equality is equal with equal contents" do
        array = [SqlLiteral.new("foo"), SqlLiteral.new("foo")]
        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with different contents" do
        array = [SqlLiteral.new("foo"), SqlLiteral.new("bar")]
        assert_equal 2, array.uniq.size
      end

      test 'grouped "or" equality makes a grouping node with an or node' do
        node = SqlLiteral.new("foo").eq_any([1, 2])
        assert_like %{ (foo = 1 OR foo = 2) }, compile(node)
      end

      test 'grouped "and" equality makes a grouping node with an and node' do
        node = SqlLiteral.new("foo").eq_all([1, 2])
        assert_like %{ (foo = 1 AND foo = 2) }, compile(node)
      end

      test "serialization serializes into YAML" do
        yaml_literal = SqlLiteral.new("foo").to_yaml
        assert_equal("foo", YAML.load(yaml_literal))
      end

      test "addition generates a Fragments node" do
        sql1 = Arel.sql "SELECT *"
        sql2 = Arel.sql "FROM users"
        fragments = sql1 + sql2
        assert_kind_of Arel::Nodes::Fragments, fragments
        assert_equal([sql1, sql2], fragments.values)
      end

      test "addition fails if joined with something that is not an Arel node" do
        sql = Arel.sql "SELECT *"
        assert_raises ArgumentError do
          sql + "Not a node"
        end
      end

      private
        def compile(node)
          @visitor.accept(node, Collectors::SQLString.new).value
        end
    end
  end
end
