require File.expand_path("../../../load_paths", __FILE__)

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
