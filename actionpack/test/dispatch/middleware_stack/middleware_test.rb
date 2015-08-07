require 'abstract_unit'
require 'action_dispatch/middleware/stack'

module ActionDispatch
  class MiddlewareStack
    class MiddlewareTest < ActiveSupport::TestCase
      class Omg; end

      {
        'concrete'  => Omg,
        'anonymous' => Class.new
      }.each do |name, klass|

        define_method("test_#{name}_klass") do
          stack = ActionDispatch::MiddlewareStack.new
          stack.use klass
          assert_equal klass, stack.first.klass
        end

        define_method("test_#{name}_==") do
          stack = ActionDispatch::MiddlewareStack.new
          stack.use klass
          stack.use klass
          assert_equal 2, stack.size
          assert_equal stack.first, stack.last
        end

      end

      attr_reader :stack

      def setup
        @stack = ActionDispatch::MiddlewareStack.new
      end

      def test_double_equal_works_with_classes
        k = Class.new
        stack.use k
        assert_operator stack.first, :==, k

        result = stack.first != Class.new
        assert result, 'middleware should not equal other anon class'
      end

      def test_double_equal_works_with_strings
        stack.use Omg
        assert_operator stack.first, :==, Omg.name
      end

      def test_double_equal_normalizes_strings
        stack.use Omg
        assert_operator stack.first, :==, "::#{Omg.name}"
      end
    end
  end
end
