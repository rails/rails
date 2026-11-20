# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_support/log_subscriber/test_helper"
require "rack/test"

module ApplicationTests
  module RackTests
    class LoggerTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation
      include Rack::Test::Methods

      def setup
        build_app
        add_to_config <<-RUBY
          config.logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

          middleware_logging = Class.new do
            def initialize(app)
              @app = app
            end

            def call(env)
              Rails.logger.info "Inside middleware after Rails::Rack::Logger"
              @app.call(env)
            end
          end
          config.middleware.insert_after Rails::Rack::Logger, middleware_logging
        RUBY

        app_file "app/controllers/test_controller.rb", <<-RUBY
          class TestController < ApplicationController
            class SpecialException < Exception
            end

            rescue_from SpecialException do
              head 406
            end

            def with_rescued_exception
              raise SpecialException, "Oops"
            end
          end
        RUBY

        app_file "config/routes.rb", <<-RUBY
          Rails.application.routes.draw do
            get "/test/with_rescued_exception", to: "test#with_rescued_exception"
          end
        RUBY

        require "#{app_path}/config/environment"
      end

      def teardown
        teardown_app
      end

      def logs
        @logs ||= Rails.logger.logged(:info).join("\n")
      end

      test "logger logs proper HTTP GET verb and path" do
        get "/blah"
        assert_match 'Started GET "/blah"', logs
      end

      test "logger logs proper HTTP HEAD verb and path" do
        head "/blah"
        assert_match 'Started HEAD "/blah"', logs
      end

      test "logger logs HTTP verb override" do
        post "/", _method: "put"
        assert_match 'Started PUT "/"', logs
      end

      test "logger logs HEAD requests" do
        post "/", _method: "head"
        assert_match 'Started HEAD "/"', logs
      end

      test "logger logs correct remote IP address" do
        get "/", {}, { "REMOTE_ADDR" => "127.0.0.1", "HTTP_X_FORWARDED_FOR" => "1.2.3.4" }
        assert_match 'Started GET "/" for 1.2.3.4', logs
      end

      test "logger logs the started line before lines logged by later middleware" do
        get "/blah"
        lines = Rails.logger.logged(:info)
        started = lines.index { |line| line.start_with?('Started GET "/blah"') }
        middleware = lines.index("Inside middleware after Rails::Rack::Logger")
        assert started, "Expected the started line to be logged"
        assert middleware, "Expected the middleware line to be logged"
        assert_operator started, :<, middleware
      end

      test "started line can be silenced by unsubscribing the Action Dispatch log subscriber" do
        Rails.event.unsubscribe(ActionDispatch::LogSubscriber)

        get "/blah"
        assert_no_match "Started GET", logs
        assert_match "Inside middleware after Rails::Rack::Logger", logs
      end

      test "logger logs rescued exceptions" do
        get "/test/with_rescued_exception"
        assert_match(/rescue_from handled TestController::SpecialException \(Oops\) - (?!#{app_path}\/)app\/controllers\/test_controller.rb.*with_rescued_exception/, logs)
      end
    end
  end
end
