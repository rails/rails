$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../lib')

bundler = File.join(File.dirname(__FILE__), '..', '..', 'vendor', 'gems', 'environment')
require bundler if File.exist?("#{bundler}.rb")

require 'rubygems'
require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'abstract_controller'
require 'action_view'
require 'action_view/base'
require 'action_dispatch'
require 'fixture_template'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end
