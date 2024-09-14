# frozen_string_literal: true

require "minitest"
require "active_support/testing/tagged_logging"
require "active_support/testing/setup_and_teardown"
require "active_support/testing/tests_without_assertions"
require "active_support/testing/assertions"
require "active_support/testing/error_reporter_assertions"
require "active_support/testing/deprecation"
require "active_support/testing/declarative"
require "active_support/testing/isolation"
require "active_support/testing/constant_lookup"
require "active_support/testing/time_helpers"
require "active_support/testing/constant_stubbing"
require "active_support/testing/file_fixtures"
require "active_support/testing/parallelization"
require "active_support/testing/parallelize_executor"
require "concurrent/utility/processor_counter"

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

      # Parallelizes the test suite.
      #
      # Takes a +workers+ argument that controls how many times the process
      # is forked. For each process a new database will be created suffixed
      # with the worker number.
      #
      #   test-database-0
      #   test-database-1
      #
      # If <tt>ENV["PARALLEL_WORKERS"]</tt> is set the workers argument will be ignored
      # and the environment variable will be used instead. This is useful for CI
      # environments, or other environments where you may need more workers than
      # you do for local testing.
      #
      # If the number of workers is set to +1+ or fewer, the tests will not be
      # parallelized.
      #
      # If +workers+ is set to +:number_of_processors+, the number of workers will be
      # set to the actual core count on the machine you are on.
      #
      # The default parallelization method is to fork processes. If you'd like to
      # use threads instead you can pass <tt>with: :threads</tt> to the +parallelize+
      # method. Note the threaded parallelization does not create multiple
      # databases and will not work with system tests.
      #
      #   parallelize(workers: :number_of_processors, with: :threads)
      #
      # The threaded parallelization uses minitest's parallel executor directly.
      # The processes parallelization uses a Ruby DRb server.
      #
      # Because parallelization presents an overhead, it is only enabled when the
      # number of tests to run is above the +threshold+ param. The default value is
      # 50, and it's configurable via +config.active_support.test_parallelization_threshold+.
      def parallelize(workers: :number_of_processors, with: :processes, threshold: ActiveSupport.test_parallelization_threshold)
        workers = Concurrent.processor_count if workers == :number_of_processors
        workers = ENV["PARALLEL_WORKERS"].to_i if ENV["PARALLEL_WORKERS"]

        Minitest.parallel_executor = ActiveSupport::Testing::ParallelizeExecutor.new(size: workers, with: with, threshold: threshold)
      end

      # Set up hook for parallel testing. This can be used if you have multiple
      # databases or any behavior that needs to be run after the process is forked
      # but before the tests run.
      #
      # Note: this feature is not available with the threaded parallelization.
      #
      # In your +test_helper.rb+ add the following:
      #
      #   class ActiveSupport::TestCase
      #     parallelize_setup do
      #       # create databases
      #     end
      #   end
      def parallelize_setup(&block)
        ActiveSupport::Testing::Parallelization.after_fork_hook(&block)
      end

      # Clean up hook for parallel testing. This can be used to drop databases
      # if your app uses multiple write/read databases or other clean up before
      # the tests finish. This runs before the forked process is closed.
      #
      # Note: this feature is not available with the threaded parallelization.
      #
      # In your +test_helper.rb+ add the following:
      #
      #   class ActiveSupport::TestCase
      #     parallelize_teardown do
      #       # drop databases
      #     end
      #   end
      def parallelize_teardown(&block)
        ActiveSupport::Testing::Parallelization.run_cleanup_hook(&block)
      end

      # :singleton-method: fixture_paths
      #
      # Returns the ActiveRecord::FixtureSet collection.
      #
      # In your +test_helper.rb+ you must have <tt>require "rails/test_help"</tt>.

      # :singleton-method: fixture_paths=
      #
      # :call-seq:
      #   fixture_paths=(fixture_paths)
      #
      # Sets the given path to the fixture set.
      #
      # Can also append multiple paths.
      #
      #   ActiveSupport::TestCase.fixture_paths << "component1/test/fixtures"
      #
      # In your +test_helper.rb+ you must have <tt>require "rails/test_help"</tt>.
    end

    alias_method :method_name, :name

    include ActiveSupport::Testing::TaggedLogging
    prepend ActiveSupport::Testing::SetupAndTeardown
    prepend ActiveSupport::Testing::TestsWithoutAssertions
    include ActiveSupport::Testing::Assertions
    include ActiveSupport::Testing::ErrorReporterAssertions
    include ActiveSupport::Testing::Deprecation
    include ActiveSupport::Testing::ConstantStubbing
    include ActiveSupport::Testing::TimeHelpers
    include ActiveSupport::Testing::FileFixtures
    extend ActiveSupport::Testing::Declarative

    ##
    # :method: assert_not_empty
    #
    # :call-seq:
    #   assert_not_empty(obj, msg = nil)
    #
    # Alias for: refute_empty[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_empty]

    #
    alias :assert_not_empty :refute_empty

    ##
    # :method: assert_not_equal
    #
    # :call-seq:
    #   assert_not_equal(exp, act, msg = nil)
    #
    # Alias for: refute_equal[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_equal]

    #
    alias :assert_not_equal :refute_equal

    ##
    # :method: assert_not_in_delta
    #
    # :call-seq:
    #   assert_not_in_delta(exp, act, delta = 0.001, msg = nil)
    #
    # Alias for: refute_in_delta[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_in_delta]

    #
    alias :assert_not_in_delta :refute_in_delta

    ##
    # :method: assert_not_in_epsilon
    #
    # :call-seq:
    #   assert_not_in_epsilon(a, b, epsilon = 0.001, msg = nil)
    #
    # Alias for: refute_in_epsilon[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_in_epsilon]

    #
    alias :assert_not_in_epsilon :refute_in_epsilon

    ##
    # :method: assert_not_includes
    #
    # :call-seq:
    #   assert_not_includes(collection, obj, msg = nil)
    #
    # Alias for: refute_includes[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_includes]

    #
    alias :assert_not_includes :refute_includes

    ##
    # :method: assert_not_instance_of
    #
    # :call-seq:
    #   assert_not_instance_of(cls, obj, msg = nil)
    #
    # Alias for: refute_instance_of[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_instance_of]

    #
    alias :assert_not_instance_of :refute_instance_of

    ##
    # :method: assert_not_kind_of
    #
    # :call-seq:
    #   assert_not_kind_of(cls, obj, msg = nil)
    #
    # Alias for: refute_kind_of[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_kind_of]

    #
    alias :assert_not_kind_of :refute_kind_of

    ##
    # :method: assert_no_match
    #
    # :call-seq:
    #   assert_no_match(matcher, obj, msg = nil)
    #
    # Alias for: refute_match[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_match]

    #
    alias :assert_no_match :refute_match

    ##
    # :method: assert_not_nil
    #
    # :call-seq:
    #   assert_not_nil(obj, msg = nil)
    #
    # Alias for: refute_nil[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_nil]

    #
    alias :assert_not_nil :refute_nil

    ##
    # :method: assert_not_operator
    #
    # :call-seq:
    #   assert_not_operator(o1, op, o2 = UNDEFINED, msg = nil)
    #
    # Alias for: refute_operator[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_operator]

    #
    alias :assert_not_operator :refute_operator

    ##
    # :method: assert_not_predicate
    #
    # :call-seq:
    #   assert_not_predicate(o1, op, msg = nil)
    #
    # Alias for: refute_predicate[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_predicate]

    #
    alias :assert_not_predicate :refute_predicate

    ##
    # :method: assert_not_respond_to
    #
    # :call-seq:
    #   assert_not_respond_to(obj, meth, msg = nil)
    #
    # Alias for: refute_respond_to[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_respond_to]

    #
    alias :assert_not_respond_to :refute_respond_to

    ##
    # :method: assert_not_same
    #
    # :call-seq:
    #   assert_not_same(exp, act, msg = nil)
    #
    # Alias for: refute_same[https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-refute_same]

    #
    alias :assert_not_same :refute_same

    ActiveSupport.run_load_hooks(:active_support_test_case, self)

    def inspect # :nodoc:
      Object.instance_method(:to_s).bind_call(self)
    end
  end
end
