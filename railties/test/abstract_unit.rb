$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"
$:.unshift File.dirname(__FILE__) + "/../../actionpack/lib"
$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../builtin/rails_info"

require 'stringio'
require 'rubygems'
require 'test/unit'

gem 'mocha', '>= 0.9.5'
require 'mocha'

require 'active_support'
require 'active_support/test_case'

if defined?(RAILS_ROOT)
  RAILS_ROOT.replace File.dirname(__FILE__)
else
  RAILS_ROOT = File.dirname(__FILE__)
end
