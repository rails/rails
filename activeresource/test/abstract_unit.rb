root = File.expand_path('../../..', __FILE__)
begin
  require "#{root}/vendor/gems/environment"
rescue LoadError
  $:.unshift("#{root}/activesupport/lib")
  $:.unshift("#{root}/activeresource/lib")
end

require 'rubygems'
require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'active_resource'

$:.unshift "#{File.dirname(__FILE__)}/../test"
require 'setter_trap'

require 'logger'
ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

begin
  require 'ruby-debug'
rescue LoadError
end
