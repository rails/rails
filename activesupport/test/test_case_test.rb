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

    if defined?(MiniTest::Assertions) && TestCase < MiniTest::Assertions
      def test_standard_error_raised_within_setup_callback_is_puked
        tc = Class.new(TestCase) do
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

      def test_standard_error_raised_within_teardown_callback_is_puked
        tc = Class.new(TestCase) do
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

      def test_passthrough_exception_raised_within_test_method_is_not_rescued
        tc = Class.new(TestCase) do
          def test_which_raises_interrupt; raise Interrupt; end
        end

        test_name = 'test_which_raises_interrupt'
        fr = FakeRunner.new

        test = tc.new test_name
        assert_raises(Interrupt) { test.run fr }
      end

      def test_passthrough_exception_raised_within_setup_callback_is_not_rescued
        tc = Class.new(TestCase) do
          setup :callback_which_raises_interrupt
          def callback_which_raises_interrupt; raise Interrupt; end
          def test_true; assert true end
        end

        test_name = 'test_true'
        fr = FakeRunner.new

        test = tc.new test_name
        assert_raises(Interrupt) { test.run fr }
      end

      def test_passthrough_exception_raised_within_teardown_callback_is_not_rescued
        tc = Class.new(TestCase) do
          teardown :callback_which_raises_interrupt
          def callback_which_raises_interrupt; raise Interrupt; end
          def test_true; assert true end
        end

        test_name = 'test_true'
        fr = FakeRunner.new

        test = tc.new test_name
        assert_raises(Interrupt) { test.run fr }
      end
    end
  end
end
