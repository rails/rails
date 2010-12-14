require 'helper'

module Arel
  module FactoryMethods
    class TestFactoryMethods < MiniTest::Unit::TestCase
      class Factory
        include Arel::FactoryMethods
      end

      def setup
        @factory = Factory.new
      end

      def test_create_join
        join = @factory.create_join :one, :two
        assert_kind_of Nodes::Join, join
        assert_equal :two, join.constraint
      end

      def test_create_on
        on = @factory.create_on :one
        assert_instance_of Nodes::On, on
        assert_equal :one, on.expr
      end
    end
  end
end
