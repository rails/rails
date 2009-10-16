ORIG_ARGV = ARGV.dup

require 'rubygems'
gem 'rack', '~> 1.0.0'
gem 'rack-test', '~> 0.5.0'

$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"
$:.unshift File.dirname(__FILE__) + "/../../activerecord/lib"
$:.unshift File.dirname(__FILE__) + "/../../actionpack/lib"
$:.unshift File.dirname(__FILE__) + "/../../actionmailer/lib"
$:.unshift File.dirname(__FILE__) + "/../../activeresource/lib"
$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../builtin/rails_info"

require 'stringio'
require 'test/unit'
require 'fileutils'

require 'active_support'
require 'active_support/core_ext/logger'
require 'active_support/test_case'

require 'action_controller'
require 'rails'

Rails::Initializer.run do |config|
  config.root = File.dirname(__FILE__)
end