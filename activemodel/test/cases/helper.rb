require File.expand_path('../../../../load_paths', __FILE__)

require 'config'
require 'active_model'
require 'active_support/core_ext/string/access'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

require 'active_support/testing/autorun'
