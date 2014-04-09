require 'helper'
require 'arel/visitors/bind_visitor'
require 'support/fake_record'

module Arel
  module Visitors
    class TestBindVisitor < Arel::Test
      attr_reader :collector

      def setup
        @collector = Collectors::SQLString.new
        super
      end

      ##
      # Tests visit_Arel_Nodes_Assignment correctly
      # substitutes binds with values from block
      def test_assignment_binds_are_substituted
        table = Table.new(:users)
        um = Arel::UpdateManager.new Table.engine
        bp = Nodes::BindParam.new '?'
        um.set [[table[:name], bp]]
        visitor = Class.new(Arel::Visitors::ToSql) {
          include Arel::Visitors::BindVisitor
        }.new Table.engine.connection

        assignment = um.ast.values[0]
        actual = visitor.accept(assignment, collector) {
          "replace"
        }
        assert actual
        value = actual.value
        assert_like "\"name\" = replace", value
      end

      def test_visitor_yields_on_binds
        visitor = Class.new(Arel::Visitors::ToSql) {
          def initialize omg
          end

          include Arel::Visitors::BindVisitor
        }.new nil

        bp = Nodes::BindParam.new 'omg'
        called = false
        visitor.accept(bp, collector) { called = true }
        assert called
      end

      def test_visitor_only_yields_on_binds
        visitor = Class.new(Arel::Visitors::ToSql) {
          def initialize omg
          end

          include Arel::Visitors::BindVisitor
        }.new(nil)

        bp = Arel.sql 'omg'
        called = false

        visitor.accept(bp, collector) { called = true }
        refute called
      end
    end
  end
end
