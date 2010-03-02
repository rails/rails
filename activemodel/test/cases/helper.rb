require File.expand_path('../../../../load_paths', __FILE__)

lib = File.expand_path("#{File.dirname(__FILE__)}/../../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

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
