require 'helper'
require 'arel/visitors/bind_visitor'
require 'support/fake_record'

module Arel
  module Visitors
    class TestBindVisitor < MiniTest::Unit::TestCase 
      
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
        actual = visitor.accept(assignment) { "replace" } 
        actual.must_be_like "\"name\" = replace"
      end

      def test_visitor_yields_on_binds
        visitor = Class.new(Arel::Visitors::Visitor) {
          def initialize omg
          end

          include Arel::Visitors::BindVisitor
        }.new nil

        bp = Nodes::BindParam.new 'omg'
        called = false
        visitor.accept(bp) { called = true }
        assert called
      end

      def test_visitor_only_yields_on_binds
        visitor = Class.new(Arel::Visitors::Visitor) {
          def initialize omg
          end

          include Arel::Visitors::BindVisitor
        }.new(nil)

        bp = Arel.sql 'omg'
        called = false

        assert_raises(TypeError) {
          visitor.accept(bp) { called = true }
        }
        refute called
      end
    end
  end
end
