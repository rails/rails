# frozen_string_literal: true

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
    config.root = __dir__
  end
end

class ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  # Skips the current run on Rubinius using Minitest::Assertions#skip
  private def rubinius_skip(message = "")
    skip message if RUBY_ENGINE == "rbx"
  end
  # Skips the current run on JRuby using Minitest::Assertions#skip
  private def jruby_skip(message = "")
    skip message if defined?(JRUBY_VERSION)
  end
end
