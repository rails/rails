# frozen_string_literal: true

require_relative "../../tools/strict_warnings"

ORIG_ARGV = ARGV.dup

require "bundler/setup"
require "active_support/core_ext/kernel/reporting"

silence_warnings do
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"
require "active_support/testing/error_reporter_assertions"

ENV["NO_RELOAD"] = "1"
require "active_support"

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport.deprecator.behavior = :raise

ActiveSupport::Cache.format_version = 7.1

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

class ActiveSupport::TestCase
  if Process.respond_to?(:fork) && !Gem.win_platform?
    parallelize
  else
    parallelize(with: :threads)
  end

  include ActiveSupport::Testing::MethodCallAssertions
  include ActiveSupport::Testing::ErrorReporterAssertions
end

require_relative "../../tools/test_common"
