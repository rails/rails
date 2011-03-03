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
          mw = Middleware.new klass
          assert_equal klass, mw.klass
        end

        define_method("test_#{name}_==") do
          mw1 = Middleware.new klass
          mw2 = Middleware.new klass
          assert_equal mw1, mw2
        end

      end

      def test_string_class
        mw = Middleware.new Omg.name
        assert_equal Omg, mw.klass
      end

      def test_double_equal_works_with_classes
        k = Class.new
        mw = Middleware.new k
        assert_operator mw, :==, k

        result = mw != Class.new
        assert result, 'middleware should not equal other anon class'
      end

      def test_double_equal_works_with_strings
        mw = Middleware.new Omg
        assert_operator mw, :==, Omg.name
      end

      def test_double_equal_normalizes_strings
        mw = Middleware.new Omg
        assert_operator mw, :==, "::#{Omg.name}"
      end

      def test_middleware_loads_classnames_from_cache
        mw = Class.new(Middleware) {
          attr_accessor :classcache
        }.new(Omg.name)

        fake_cache    = { mw.name => Omg }
        mw.classcache = fake_cache

        assert_equal Omg, mw.klass

        fake_cache[mw.name] = Middleware
        assert_equal Middleware, mw.klass
      end

      def test_middleware_always_returns_class
        mw = Class.new(Middleware) {
          attr_accessor :classcache
        }.new(Omg)

        fake_cache    = { mw.name => Middleware }
        mw.classcache = fake_cache

        assert_equal Omg, mw.klass
      end
    end
  end
end
