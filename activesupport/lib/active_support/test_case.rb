require 'test/unit/testcase'
require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/assertions'
require 'active_support/testing/deprecation'
require 'active_support/testing/declarative'
require 'active_support/testing/pending'
require 'active_support/testing/isolation'
require 'active_support/testing/mochaing'
require 'active_support/core_ext/kernel/reporting'

module ActiveSupport
  class TestCase < ::Test::Unit::TestCase
    if defined?(MiniTest::Assertions) && TestCase < MiniTest::Assertions
      Assertion = MiniTest::Assertion
      alias_method :method_name, :name if method_defined? :name
      alias_method :method_name, :__name__ if method_defined? :__name__
    else
      Assertion = Test::Unit::AssertionFailedError

      undef :default_test
    end

    $tags = {}
    def self.for_tag(tag)
      yield if $tags[tag]
    end

    include ActiveSupport::Testing::SetupAndTeardown
    include ActiveSupport::Testing::Assertions
    include ActiveSupport::Testing::Deprecation
    include ActiveSupport::Testing::Pending
    extend ActiveSupport::Testing::Declarative
  end
end
