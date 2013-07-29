require File.expand_path('../../../../load_paths', __FILE__)

require 'config'
require 'active_model'
require 'active_support/core_ext/string/access'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

require 'active_support/testing/autorun'

def assert_raise(*args)
  e = super(*args)
  assert_match(e.message, args.last, "The exception's message was incorrect") if args.last.is_a?(String)
end
