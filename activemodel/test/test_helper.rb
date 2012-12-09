require 'rubygems'
require 'test/unit'

gem 'mocha', '>= 0.13.1'
require 'mocha/setup'

require 'active_model'
require 'active_model/state_machine'

$:.unshift File.expand_path('../../../activesupport/lib', __FILE__)
require 'active_support'
require 'active_support/test_case'

class ActiveModel::TestCase < ActiveSupport::TestCase
end

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
end
