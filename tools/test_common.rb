# frozen_string_literal: true

require_relative "support/leak_checker"

module TestCommons
  module DisableSkipping # :nodoc:
    private
      def skip(message = nil, *)
        flunk "Skipping tests is not allowed in this environment (#{message})\n" \
          "Tests should only be skipped when the environment is missing a required dependency.\n" \
          "This should never happen on CI."
      end
  end

  module MandatoryTestClass
    class << self
      attr_accessor :test_class
      attr_accessor :framework
    end

    def self.finished_loading
      self.test_class = nil
    end

    def inherited(child)
      super

      if MandatoryTestClass.test_class && !(child <= MandatoryTestClass.test_class)
        raise "All #{MandatoryTestClass.framework} tests must inherit from #{MandatoryTestClass.test_class}"
      end
    end
  end

  extend self

  def allow_test_case
    test_class_was = MandatoryTestClass.test_class
    MandatoryTestClass.test_class = nil
    yield
  ensure
    MandatoryTestClass.test_class = test_class_was
  end

  def augment(klass)
    klass.alias_method :force_skip, :skip

    if ENV["BUILDKITE"]
      klass.include(DisableSkipping)
    end

    klass.prepend(LeakChecker)
    klass.extend(MandatoryTestClass)
  end
end

ENV["RAILS_TEST_EXECUTABLE"] = "bin/test"
if ENV["BUILDKITE"]
  ENV.delete("CI") # CI has affect on the applications, and we don't want it applied to the apps.
end

require "active_support/test_case"
TestCommons.augment(ActiveSupport::TestCase)
TestCommons.augment(RailsTestCase) if defined?(RailsTestCase)
