gem 'minitest' # make sure we get the gem, not stdlib
require 'minitest'
require 'active_support/testing/tagged_logging'
require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/assertions'
require 'active_support/testing/deprecation'
require 'active_support/testing/declarative'
require 'active_support/testing/isolation'
require 'active_support/testing/constant_lookup'
require 'active_support/testing/time_helpers'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/deprecation'

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
      #   ActiveSupport::TestCase.test_order # => :sorted
      #
      # Possible values are +:random+, +:parallel+, +:alpha+, +:sorted+.
      # Defaults to +:sorted+.
      def test_order
        test_order = ActiveSupport.test_order

        if test_order.nil?
          ActiveSupport::Deprecation.warn "You did not specify a value for the " \
            "configuration option `active_support.test_order`. In Rails 5, " \
            "the default value of this option will change from `:sorted` to " \
            "`:random`.\n" \
            "To disable this warning and keep the current behavior, you can add " \
            "the following line to your `config/environments/test.rb`:\n" \
            "\n" \
            "  Rails.application.configure do\n" \
            "    config.active_support.test_order = :sorted\n" \
            "  end\n" \
            "\n" \
            "Alternatively, you can opt into the future behavior by setting this " \
            "option to `:random`."

          test_order = :sorted
          self.test_order = test_order
        end

        test_order
      end

      alias :my_tests_are_order_dependent! :i_suck_and_my_tests_are_order_dependent!
    end

    alias_method :method_name, :name

    include ActiveSupport::Testing::TaggedLogging
    include ActiveSupport::Testing::SetupAndTeardown
    include ActiveSupport::Testing::Assertions
    include ActiveSupport::Testing::Deprecation
    include ActiveSupport::Testing::TimeHelpers
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

    # Fails if the block raises an exception.
    #
    #   assert_nothing_raised do
    #     ...
    #   end
    def assert_nothing_raised(*args)
      yield
    end
  end
end
