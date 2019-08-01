# frozen_string_literal: true

require "active_model"

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

require "active_support/testing/autorun"
require "active_support/core_ext/integer/time"

require_relative "../../../tools/test_common"
