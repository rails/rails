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

# FIXME: We force sorted test order below, but minitest includes --seed SEED in
# the printed run options, which could be misleading, since users could assume
# from that trace that tests are being randomized.
MiniTest::Unit.class_eval do
  alias original_help help
  def help
    original_help.sub(/--seed\s+\d+\s*/, '')
  end
end

module ActiveSupport
  class TestCase < ::MiniTest::Unit::TestCase
    Assertion = MiniTest::Assertion
    alias_method :method_name, :__name__

    $tags = {}
    def self.for_tag(tag)
      yield if $tags[tag]
    end

    # FIXME: We have tests that depend on run order, we should fix that and
    # remove this method (and remove the MiniTest::Unit help hack above).
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
