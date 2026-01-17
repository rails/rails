# frozen_string_literal: true

require_relative "../../tools/strict_warnings"
require_relative "../../tools/test_helper"
require "active_model"

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveModel.deprecator.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

class ActiveModel::TestCase < RailsTestCase
end
