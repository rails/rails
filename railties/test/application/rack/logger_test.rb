require "isolation/abstract_unit"
require "active_support/log_subscriber/test_helper"
require "rack/test"

module ApplicationTests
  module RackTests
    class LoggerTest < Test::Unit::TestCase
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
        teardown_app
      end

      def logs
        @logs ||= @logger.logged(:info).join("\n")
      end

      test "logger logs proper HTTP verb and path" do
        get "/blah"
        wait
        assert_match 'Started GET "/blah"', logs
      end

      test "logger logs HTTP verb override" do
        post "/", :_method => 'put'
        wait
        assert_match 'Started PUT "/"', logs
      end

      test "logger logs HEAD requests" do
        post "/", :_method => 'head'
        wait
        assert_match 'Started HEAD "/"', logs
      end
    end
  end
end
