# frozen_string_literal: true

ORIG_ARGV = ARGV.dup

require "active_support/core_ext/kernel/reporting"

silence_warnings do
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

require "active_support/testing/autorun"

ENV["NO_RELOAD"] = "1"
require "active_support"

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Default to old to_time behavior but allow running tests with new behavior
ActiveSupport.to_time_preserves_timezone = ENV["PRESERVE_TIMEZONES"] == "1"

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

require_relative "../../tools/test_common"
