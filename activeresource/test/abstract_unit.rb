$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/.')

require 'active_resource'
require 'test/unit'
require 'active_support/breakpoint'

require "#{File.dirname(__FILE__)}/http_mock"