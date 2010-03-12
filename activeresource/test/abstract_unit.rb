require File.expand_path('../../../load_paths', __FILE__)

lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'rubygems'
require 'test/unit'
require 'active_resource'
require 'active_support'
require 'active_support/test_case'

require 'setter_trap'

require 'logger'
ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

begin
  require 'ruby-debug'
rescue LoadError
end
