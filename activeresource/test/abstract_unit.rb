require 'rubygems'
require 'test/unit'
require 'active_support/test_case'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_resource'

$:.unshift "#{File.dirname(__FILE__)}/../test"
require 'setter_trap'

require 'logger'
ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

begin
  require 'ruby-debug'
rescue LoadError
end
