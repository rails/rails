# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_support/log_subscriber/test_helper"
require "rack/test"

module ApplicationTests
  module RackTests
    class LoggerTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation
      include ActiveSupport::LogSubscriber::TestHelper
      include Rack::Test::Methods

      setup do
        build_app
        require "#{app_path}/config/environment"
      end

      teardown do
        teardown_app
      end

      test "loads routes on request" do
        assert_equal(false, Rails.application.routes_reloader.loaded)

        get "/test"

        assert_equal(true, Rails.application.routes_reloader.loaded)
      end

      test "loads routes only once" do
        assert_called(Rails.application.routes_reloader, :execute_unless_loaded, 1) do
          5.times { get "/test" }
        end
      end
    end
  end
end
