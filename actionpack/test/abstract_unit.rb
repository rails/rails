$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib/active_support')
$:.unshift(File.dirname(__FILE__) + '/fixtures/helpers')

require 'yaml'
require 'test/unit'
require 'action_controller'
require 'breakpoint'
require 'action_controller/test_process'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

ActionController::Base.logger = nil
ActionController::Base.ignore_missing_templates = false
ActionController::Routing::Routes.reload rescue nil


# Wrap tests that use Mocha and skip if unavailable.
def uses_mocha(test_name)
  require 'mocha'
  require 'stubba'
  yield
rescue LoadError
  $stderr.puts "Skipping #{test_name} tests. `gem install mocha` and try again."
end
