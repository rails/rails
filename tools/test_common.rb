# frozen_string_literal: true

ActiveSupport::TestCase.alias_method :force_skip, :skip

if ENV["BUILDKITE"]
  require "minitest-ci"
  ENV.delete("CI") # CI has affect on the applications, and we don't want it applied to the apps.

  Minitest::Ci.report_dir = File.join(__dir__, "../test-reports/#{ENV['BUILDKITE_JOB_ID']}")

  module DisableSkipping # :nodoc:
    private
      def skip(message = nil, *)
        flunk "Skipping tests is not allowed in this environment (#{message})\n" \
          "Tests should only be skipped when the environment is missing a required dependency.\n" \
          "This should never happen on CI."
      end
  end
  ActiveSupport::TestCase.include(DisableSkipping)
end
