ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../../../load_paths", __FILE__)

require 'stringio'
require 'minitest/autorun'
require 'fileutils'

require 'active_support'

require 'action_controller'
require 'rails/all'

module TestApp
  class Application < Rails::Application
    config.root = File.dirname(__FILE__)
    config.secret_token_key = 'b3c631c314c0bbca50c1b2843150fe33'
  end
end
