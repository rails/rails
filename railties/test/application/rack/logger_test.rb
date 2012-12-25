require "isolation/abstract_unit"
require "active_support/log_subscriber/test_helper"
require "rack/test"

module ApplicationTests
  module RackTests
    class LoggerTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation
      include ActiveSupport::LogSubscriber::TestHelper
      include Rack::Test::Methods

      def setup
        build_app
        require "#{app_path}/config/environment"
        super
        @logger = MockLogger.new
        Rails.stubs(:logger).returns(@logger)
      end

      def teardown
        super
        teardown_app
      end

      def logs
        @logs ||= @logger.logged(:info).join("\n")
      end

      test "logger logs proper HTTP GET verb and path" do
        get "/blah"
        wait
        assert_match 'Started GET "/blah"', logs
      end

      test "logger logs proper HTTP HEAD verb and path" do
        head "/blah"
        wait
        assert_match 'Started HEAD "/blah"', logs
      end

      test "logger logs HTTP verb override" do
        post "/", _method: 'put'
        wait
        assert_match 'Started PUT "/"', logs
      end

      test "logger logs HEAD requests" do
        post "/", _method: 'head'
        wait
        assert_match 'Started HEAD "/"', logs
      end
    end
  end
end
