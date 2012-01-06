require 'abstract_unit'

module ActiveSupport
  class TestCaseTest < ActiveSupport::TestCase
    class FakeRunner
      attr_reader :puked

      def initialize
        @puked = []
      end

      def puke(klass, name, e)
        @puked << [klass, name, e]
      end

      def options
        nil
      end
    end

    def test_callback_with_exception
      tc = Class.new(TestCase) do
        def self.name
          nil
        end

        setup :bad_callback
        def bad_callback; raise 'oh noes' end
        def test_true; assert true end
      end

      test_name = 'test_true'
      fr = FakeRunner.new

      test = tc.new test_name
      test.run fr
      klass, name, exception = *fr.puked.first

      assert_equal tc, klass
      assert_equal test_name, name
      assert_equal 'oh noes', exception.message
    end

    def test_teardown_callback_with_exception
      tc = Class.new(TestCase) do
        def self.name
          nil
        end

        teardown :bad_callback
        def bad_callback; raise 'oh noes' end
        def test_true; assert true end
      end

      test_name = 'test_true'
      fr = FakeRunner.new

      test = tc.new test_name
      test.run fr
      klass, name, exception = *fr.puked.first

      assert_equal tc, klass
      assert_equal test_name, name
      assert_equal 'oh noes', exception.message
    end
  end
end
