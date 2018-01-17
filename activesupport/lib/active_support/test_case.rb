# frozen_string_literal: true

gem "minitest" # make sure we get the gem, not stdlib
require "minitest"
require "active_support/testing/tagged_logging"
require "active_support/testing/setup_and_teardown"
require "active_support/testing/assertions"
require "active_support/testing/deprecation"
require "active_support/testing/declarative"
require "active_support/testing/isolation"
require "active_support/testing/constant_lookup"
require "active_support/testing/time_helpers"
require "active_support/testing/file_fixtures"

module ActiveSupport
  class TestCase < ::Minitest::Test
    Assertion = Minitest::Assertion

    class << self
      # Sets the order in which test cases are run.
      #
      #   ActiveSupport::TestCase.test_order = :random # => :random
      #
      # Valid values are:
      # * +:random+   (to run tests in random order)
      # * +:parallel+ (to run tests in parallel)
      # * +:sorted+   (to run tests alphabetically by method name)
      # * +:alpha+    (equivalent to +:sorted+)
      def test_order=(new_order)
        ActiveSupport.test_order = new_order
      end

      # Returns the order in which test cases are run.
      #
      #   ActiveSupport::TestCase.test_order # => :random
      #
      # Possible values are +:random+, +:parallel+, +:alpha+, +:sorted+.
      # Defaults to +:random+.
      def test_order
        ActiveSupport.test_order ||= :random
      end
    end

    alias_method :method_name, :name

    include ActiveSupport::Testing::TaggedLogging
    include ActiveSupport::Testing::SetupAndTeardown
    include ActiveSupport::Testing::Assertions
    include ActiveSupport::Testing::Deprecation
    include ActiveSupport::Testing::TimeHelpers
    include ActiveSupport::Testing::FileFixtures
    extend ActiveSupport::Testing::Declarative

    # test/unit backwards compatibility methods
    alias :assert_raise :assert_raises
    alias :assert_not_empty :refute_empty
    alias :assert_not_equal :refute_equal
    alias :assert_not_in_delta :refute_in_delta
    alias :assert_not_in_epsilon :refute_in_epsilon
    alias :assert_not_includes :refute_includes
    alias :assert_not_instance_of :refute_instance_of
    alias :assert_not_kind_of :refute_kind_of
    alias :assert_no_match :refute_match
    alias :assert_not_nil :refute_nil
    alias :assert_not_operator :refute_operator
    alias :assert_not_predicate :refute_predicate
    alias :assert_not_respond_to :refute_respond_to
    alias :assert_not_same :refute_same

    ActiveSupport.run_load_hooks(:active_support_test_case, self)
  end
end
