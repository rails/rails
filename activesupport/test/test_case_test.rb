require 'abstract_unit'

module ActiveSupport
  class TestCaseTest < ActiveSupport::TestCase
    IS_MINITEST = defined?(MiniTest::Assertions) && TestCase < MiniTest::Assertions 

    class FakeRunner
      attr_reader :puked

      def initialize
        @puked = []
      end

      def puke(klass, name, e)
        @puked << [klass, name, e]
      end

      unless IS_MINITEST
        def add_error(e)
          puke(nil, nil, e)
        end

        def add_run
        end

        def add_assertion
        end

        def add_failure(msg, locations=nil)
        end
      end
    end

    def test_callback_with_exception
      tc = Class.new(TestCase) do
        setup :bad_callback
        def bad_callback; raise 'oh noes' end
        def test_true; assert true end
      end

      test_name = 'test_true'
      fr = FakeRunner.new

      test = tc.new test_name
      test.run(fr) {}
      klass, name, exception = *fr.puked.first

      if IS_MINITEST
        assert_equal tc, klass
        assert_equal test_name, name
      end

      assert_match %r{oh noes}, exception.message
    end

    def test_teardown_callback_with_exception
      tc = Class.new(TestCase) do
        teardown :bad_callback
        def bad_callback; raise 'oh noes' end
        def test_true; assert true end
      end

      test_name = 'test_true'
      fr = FakeRunner.new

      test = tc.new test_name
      test.run(fr) {}
      klass, name, exception = *fr.puked.first

      if IS_MINITEST
        assert_equal tc, klass
        assert_equal test_name, name
      end

      assert_match %r{oh noes}, exception.message
    end
  end
end
