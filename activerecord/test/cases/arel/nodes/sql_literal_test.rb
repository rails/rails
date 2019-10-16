# frozen_string_literal: true

require_relative "../helper"
require "yaml"

module Arel
  module Nodes
    class SqlLiteralTest < Arel::Spec
      before do
        @visitor = Visitors::ToSql.new Table.engine.connection
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      describe "sql" do
        it "makes a sql literal node" do
          sql = Arel.sql "foo"
          _(sql).must_be_kind_of Arel::Nodes::SqlLiteral
        end
      end

      describe "count" do
        it "makes a count node" do
          node = SqlLiteral.new("*").count
          _(compile(node)).must_be_like %{ COUNT(*) }
        end

        it "makes a distinct node" do
          node = SqlLiteral.new("*").count true
          _(compile(node)).must_be_like %{ COUNT(DISTINCT *) }
        end
      end

      describe "equality" do
        it "makes an equality node" do
          node = SqlLiteral.new("foo").eq(1)
          _(compile(node)).must_be_like %{ foo = 1 }
        end

        it "is equal with equal contents" do
          array = [SqlLiteral.new("foo"), SqlLiteral.new("foo")]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different contents" do
          array = [SqlLiteral.new("foo"), SqlLiteral.new("bar")]
          assert_equal 2, array.uniq.size
        end
      end

      describe 'grouped "or" equality' do
        it "makes a grouping node with an or node" do
          node = SqlLiteral.new("foo").eq_any([1, 2])
          _(compile(node)).must_be_like %{ (foo = 1 OR foo = 2) }
        end
      end

      describe 'grouped "and" equality' do
        it "makes a grouping node with an and node" do
          node = SqlLiteral.new("foo").eq_all([1, 2])
          _(compile(node)).must_be_like %{ (foo = 1 AND foo = 2) }
        end
      end

      describe "serialization" do
        it "serializes into YAML" do
          yaml_literal = SqlLiteral.new("foo").to_yaml
          assert_equal("foo", YAML.load(yaml_literal))
        end
      end
    end
  end
end
