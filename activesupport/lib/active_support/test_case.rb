gem 'minitest' # make sure we get the gem, not stdlib
require 'minitest/spec'
require 'active_support/testing/tagged_logging'
require 'active_support/testing/setup_and_teardown'
require 'active_support/testing/assertions'
require 'active_support/testing/deprecation'
require 'active_support/testing/pending'
require 'active_support/testing/isolation'
require 'active_support/testing/constant_lookup'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/deprecation'

begin
  silence_warnings { require 'mocha/setup' }
rescue LoadError
end

module ActiveSupport
  class TestCase < ::MiniTest::Spec

    # Use AS::TestCase for the base class when describing a model
    register_spec_type(self) do |desc|
      Class === desc && desc < ActiveRecord::Base
    end

    Assertion = MiniTest::Assertion
    alias_method :method_name, :__name__

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

    def self.describe(text)
      if block_given?
        super
      else
        message = "`describe` without a block is deprecated, please switch to: `def self.name; #{text.inspect}; end`\n"
        ActiveSupport::Deprecation.warn message

        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def self.name
            "#{text}"
          end
        RUBY_EVAL
      end
    end

    class << self
      alias :test :it
    end

    # test/unit backwards compatibility methods
    alias :assert_raise :assert_raises
    alias :assert_not_nil :refute_nil
    alias :assert_not_equal :refute_equal
    alias :assert_no_match :refute_match
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
