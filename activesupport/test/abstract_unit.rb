require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_support'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true
