bundled = "#{File.dirname(__FILE__)}/../vendor/gems/environment"
if File.exist?("#{bundled}.rb")
  require bundled
else
  $:.unshift(File.dirname(__FILE__) + '/../../lib')
  $:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')
end

require 'config'

require 'active_model'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

require 'rubygems'
require 'test/unit'

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
end
