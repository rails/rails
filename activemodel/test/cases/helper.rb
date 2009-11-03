root = File.expand_path('../../../..', __FILE__)
begin
  require "#{root}/vendor/gems/environment"
rescue LoadError
  $:.unshift("#{root}/activesupport/lib")
  $:.unshift("#{root}/activemodel/lib")
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
