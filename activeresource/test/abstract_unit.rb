require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_resource'
require 'active_resource/http_mock'
require 'active_support/breakpoint'

ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")
