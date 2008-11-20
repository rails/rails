require 'rubygems'
require 'test/unit'

gem 'mocha', '>= 0.5.5'
require 'mocha'

require 'active_model'
require 'active_model/state_machine'
require 'active_support/test_case'

class ActiveModel::TestCase < ActiveSupport::TestCase
end

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
end
