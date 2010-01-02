ORIG_ARGV = ARGV.dup

root = File.expand_path('../../..', __FILE__)
begin
  require "#{root}/vendor/gems/environment"
rescue LoadError
  %w(activesupport activemodel activerecord actionpack actionmailer activeresource railties).each do |lib|
    $:.unshift "#{root}/#{lib}/lib"
  end
end

$:.unshift "#{root}/railties/builtin/rails_info"

require 'stringio'
require 'test/unit'
require 'fileutils'

require 'active_support'
require 'active_support/core_ext/logger'
require 'active_support/test_case'

require 'action_controller'
require 'rails/all'

# TODO: Remove these hacks
class TestApp < Rails::Application
  config.root = File.dirname(__FILE__)
end
Rails.application = TestApp
