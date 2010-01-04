begin
  require File.expand_path('../../../vendor/gems/environment', __FILE__)
rescue LoadError
end

lib = File.expand_path('../../lib', __FILE__)
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'rubygems'
require 'test/unit'
require 'active_resource'
require 'active_support'

$:.unshift "#{File.dirname(__FILE__)}/../test"
require 'setter_trap'

require 'logger'
ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

begin
  require 'ruby-debug'
rescue LoadError
end
