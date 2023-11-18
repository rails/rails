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
    config.root = __dir__
  end
end

class ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream
end

ActiveSupport.on_load(:action_controller_test_case) do
  include ActionView::RailsDomTestingAssertions
end

ActiveSupport.on_load(:action_mailer_test_case) do
  include Rails::Dom::Testing::Assertions::SelectorAssertions
  include Rails::Dom::Testing::Assertions::DomAssertions
end

require_relative "../../tools/test_common"
