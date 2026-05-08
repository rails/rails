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

  extend self

  def augment(klass)
    klass.alias_method :force_skip, :skip

    if ENV["BUILDKITE"]
      klass.include(DisableSkipping)
    end

    klass.prepend(LeakChecker)
  end
end

ENV["RAILS_TEST_EXECUTABLE"] = "bin/test"
if ENV["BUILDKITE"]
  ENV.delete("CI") # CI has affect on the applications, and we don't want it applied to the apps.
end

TestCommons.augment(ActiveSupport::TestCase) if defined?(ActiveSupport::TestCase)
TestCommons.augment(RailsTestCase) if defined?(RailsTestCase)
