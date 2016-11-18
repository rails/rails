ENV["RAILS_ENV"] ||= "test"

require "stringio"
require "active_support/testing/autorun"
require "active_support/testing/stream"
require "fileutils"

require "active_support"
require "action_controller"
require "action_view"
require "rails/all"

module TestApp
  class Application < Rails::Application
    config.root = File.dirname(__FILE__)
    secrets.secret_key_base = "b3c631c314c0bbca50c1b2843150fe33"
  end
end

# Skips the current run on Rubinius using Minitest::Assertions#skip
def rubinius_skip(message = "")
  skip message if RUBY_ENGINE == "rbx"
end
# Skips the current run on JRuby using Minitest::Assertions#skip
def jruby_skip(message = "")
  skip message if defined?(JRUBY_VERSION)
end

class ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream
end
