$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'active_resource'
require 'test/unit'
require 'active_support/breakpoint'

$:.unshift(File.dirname(__FILE__) + '/.')
require 'http_mock'

ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")
