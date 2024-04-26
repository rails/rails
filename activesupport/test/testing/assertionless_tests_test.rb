# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/object/with"

module AssertionlessTestsTest
  module Tests
    def test_without_assertions
    end
  end

  class AssertionlessTestsIgnore < ActiveSupport::TestCase
    module AfterTeardown
      def after_teardown
        ActiveSupport::TestCase.with(assertionless_tests_behavior: :ignore) do
          assert_nothing_raised do
            super
          end
        end
      end
    end

    include Tests
    prepend AfterTeardown
  end

  class AssertionlessTestsLog < ActiveSupport::TestCase
    module AfterTeardown
      def after_teardown
        _out, err = capture_io do
          ActiveSupport::TestCase.with(assertionless_tests_behavior: :log) do
            super
          end
        end
        assert_match(/Test is missing assertions: `test_without_assertions` .+assertionless_tests_test\.rb:\d+/, err)
      end
    end

    include Tests
    prepend AfterTeardown
  end

  class AssertionlessTestsRaise < ActiveSupport::TestCase
    module AfterTeardown
      def after_teardown
        ActiveSupport::TestCase.with(assertionless_tests_behavior: :raise) do
          assert_raise(Minitest::Assertion,
                       match: /Test is missing assertions: `test_without_assertions` .+assertionless_tests_test\.rb:\d+/) do
            super
          end
        end
      end
    end

    include Tests
    prepend AfterTeardown
  end

  class AssertionlessTestsUnknown < ActiveSupport::TestCase
    def test_raises_when_unknown_behavior
      assert_raises(ArgumentError, match: /assertionless_tests_behavior must be one of/) do
        ActiveSupport::TestCase.assertionless_tests_behavior = :unknown
      end
    end
  end
end
