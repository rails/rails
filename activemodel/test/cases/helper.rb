$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')

require 'config'

require 'active_model'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

require 'rubygems'
require 'test/unit'
gem 'mocha', '>= 0.9.5'
require 'mocha'

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
end
