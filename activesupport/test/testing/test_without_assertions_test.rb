# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/object/with"

module TestsWithoutAssertionsTest
  module Tests
    def test_without_assertions
    end
  end

  class TestsWithoutAssertionsWarnTest < ActiveSupport::TestCase
    module AfterTeardown
      def after_teardown
        _out, err = capture_io do
          super
        rescue ActiveSupport::RaiseWarnings::WarningError
        end

        assert_match(/Test is missing assertions: `test_without_assertions` .+test_without_assertions_test\.rb:\d+/, err)
      end
    end

    include Tests
    prepend AfterTeardown
  end
end
