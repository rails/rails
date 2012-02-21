require 'helper'
require 'arel/visitors/bind_visitor'

module Arel
  module Visitors
    class TestBindVisitor < MiniTest::Unit::TestCase
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
