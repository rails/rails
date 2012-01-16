require 'minitest/spec'
require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/assertions'
require 'active_support/testing/deprecation'
require 'active_support/testing/declarative'
require 'active_support/testing/pending'
require 'active_support/testing/isolation'
require 'active_support/testing/mochaing'
require 'active_support/core_ext/kernel/reporting'

module ActiveSupport
  class TestCase < ::MiniTest::Spec

    if MiniTest::Unit::VERSION < '2.6.1'
      class << self
        alias :name :to_s
      end
    end

    # Use AS::TestCase for the base class when describing a model
    register_spec_type(self) do |desc|
      desc < ActiveRecord::Model
    end

    Assertion = MiniTest::Assertion
    alias_method :method_name, :name if method_defined? :name
    alias_method :method_name, :__name__ if method_defined? :__name__

    $tags = {}
    def self.for_tag(tag)
      yield if $tags[tag]
    end

    # FIXME: we have tests that depend on run order, we should fix that and
    # remove this method.
    def self.test_order # :nodoc:
      :sorted
    end

    include ActiveSupport::Testing::SetupAndTeardown
    include ActiveSupport::Testing::Assertions
    include ActiveSupport::Testing::Deprecation
    include ActiveSupport::Testing::Pending
    extend ActiveSupport::Testing::Declarative

    # test/unit backwards compatibility methods
    alias :assert_raise :assert_raises
    alias :assert_not_nil :refute_nil
    alias :assert_not_equal :refute_equal
    alias :assert_no_match :refute_match
    alias :assert_not_same :refute_same

    def assert_nothing_raised(*args)
      yield
    end
  end
end
