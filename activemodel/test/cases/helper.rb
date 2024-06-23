# frozen_string_literal: true

require "active_support/testing/strict_warnings"
require "active_model"

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveModel.deprecator.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"
require "active_support/core_ext/integer/time"

class ActiveModel::TestCase < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
end

require_relative "../../../tools/test_common"
