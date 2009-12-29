begin
  require File.expand_path('../../../../vendor/gems/environment', __FILE__)
rescue LoadError
end

lib = File.expand_path('../../../lib', __FILE__)
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'config'
require 'active_model'
require 'active_model/test_case'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

require 'rubygems'
require 'test/unit'

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
end
