# frozen_string_literal: true

require "active_support/testing/strict_warnings"

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
    config.root = File.expand_path("../../", __FILE__)
  end
end

class ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream
end

require_relative "../../tools/test_common"
