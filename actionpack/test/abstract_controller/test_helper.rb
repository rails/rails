$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'action_controller'
require 'action_view/base'
require 'fixture_template'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'action_controller/abstract'
# require 'action_controller/abstract/base'
# require 'action_controller/abstract/renderer'
# require 'action_controller/abstract/layouts'
# require 'action_controller/abstract/callbacks'
# require 'action_controller/abstract/helpers'