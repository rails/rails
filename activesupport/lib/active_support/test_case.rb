gem 'minitest' # make sure we get the gem, not stdlib
require 'minitest/unit'
require 'active_support/testing/tagged_logging'
require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/assertions'
require 'active_support/testing/deprecation'
require 'active_support/testing/pending'
require 'active_support/testing/declarative'
require 'active_support/testing/isolation'
require 'active_support/testing/constant_lookup'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/deprecation'

begin
  silence_warnings { require 'mocha/setup' }
rescue LoadError
end

module Minitest # :nodoc:
  class << self
    remove_method :__run
  end

  def self.__run reporter, options # :nodoc:
    # FIXME: MT5's runnables is not ordered. This is needed because
    # we have have tests have cross-class order-dependent bugs.
    suites = Runnable.runnables.sort_by { |ts| ts.name.to_s }

    parallel, serial = suites.partition { |s| s.test_order == :parallel }

    ParallelEach.new(parallel).map { |suite| suite.run reporter, options } +
     serial.map { |suite| suite.run reporter, options }
  end
end

module ActiveSupport
  class TestCase < ::Minitest::Test
    Assertion = Minitest::Assertion

    alias_method :method_name, :name

    $tags = {}
    def self.for_tag(tag)
      yield if $tags[tag]
    end

    # FIXME: we have tests that depend on run order, we should fix that and
    # remove this method.
    def self.test_order # :nodoc:
      :sorted
    end

    include ActiveSupport::Testing::TaggedLogging
    include ActiveSupport::Testing::SetupAndTeardown
    include ActiveSupport::Testing::Assertions
    include ActiveSupport::Testing::Deprecation
    include ActiveSupport::Testing::Pending
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
