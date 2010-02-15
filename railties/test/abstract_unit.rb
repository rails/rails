ORIG_ARGV = ARGV.dup

require File.expand_path("../../../bundler", __FILE__)
$:.unshift File.expand_path("../../builtin/rails_info", __FILE__)

lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'edge_rails'

require 'stringio'
require 'test/unit'
require 'fileutils'

require 'active_support'
require 'active_support/core_ext/logger'

require 'action_controller'
require 'rails/all'

# TODO: Remove these hacks
class TestApp < Rails::Application
  config.root = File.dirname(__FILE__)
end
Rails.application = TestApp
