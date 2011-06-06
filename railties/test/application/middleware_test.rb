require 'isolation/abstract_unit'
require 'stringio'

module ApplicationTests
  class MiddlewareTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "default middleware stack" do
      boot!

      assert_equal [
        "ActionDispatch::Static",
        "Rack::Lock",
        "ActiveSupport::Cache::Strategy::LocalCache",
        "Rack::Runtime",
        "Rails::Rack::Logger",
        "ActionDispatch::ShowExceptions",
        "ActionDispatch::RemoteIp",
        "Rack::Sendfile",
        "ActionDispatch::Callbacks",
        "ActiveRecord::ConnectionAdapters::ConnectionManagement",
        "ActiveRecord::QueryCache",
        "ActionDispatch::Cookies",
        "ActionDispatch::Session::CookieStore",
        "ActionDispatch::Flash",
        "ActionDispatch::ParamsParser",
        "Rack::MethodOverride",
        "ActionDispatch::Head",
        "ActionDispatch::BestStandardsSupport"
      ], middleware
    end

    test "removing Active Record omits its middleware" do
      use_frameworks []
      boot!
      assert !middleware.include?("ActiveRecord::ConnectionAdapters::ConnectionManagement")
      assert !middleware.include?("ActiveRecord::QueryCache")
    end

    test "removes lock if allow concurrency is set" do
      add_to_config "config.allow_concurrency = true"
      boot!
      assert !middleware.include?("Rack::Lock")
    end

    test "removes static asset server if serve_static_assets is disabled" do
      add_to_config "config.serve_static_assets = false"
      boot!
      assert !middleware.include?("ActionDispatch::Static")
    end

    test "can delete a middleware from the stack" do
      add_to_config "config.middleware.delete ActionDispatch::Static"
      boot!
      assert !middleware.include?("ActionDispatch::Static")
    end

    test "includes show exceptions even action_dispatch.show_exceptions is disabled" do
      add_to_config "config.action_dispatch.show_exceptions = false"
      boot!
      assert middleware.include?("ActionDispatch::ShowExceptions")
    end

    test "use middleware" do
      use_frameworks []
      add_to_config "config.middleware.use Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.last
    end

    test "insert middleware after" do
      add_to_config "config.middleware.insert_after ActionDispatch::Static, Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.second
    end

    test "RAILS_CACHE does not respond to middleware" do
      add_to_config "config.cache_store = :memory_store"
      boot!
      assert_equal "Rack::Runtime", middleware.third
    end

    test "RAILS_CACHE does respond to middleware" do
      boot!
      assert_equal "Rack::Runtime", middleware.fourth
    end

    test "insert middleware before" do
      add_to_config "config.middleware.insert_before ActionDispatch::Static, Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.first
    end

    # x_sendfile_header middleware
    test "config.action_dispatch.x_sendfile_header defaults to ''" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          send_file __FILE__
        end
      end

      get "/"
      assert_equal File.read(__FILE__), last_response.body
    end

    test "config.action_dispatch.x_sendfile_header can be set" do
      make_basic_app do |app|
        app.config.action_dispatch.x_sendfile_header = "X-Sendfile"
      end

      class ::OmgController < ActionController::Base
        def index
          send_file __FILE__
        end
      end

      get "/"
      assert_equal File.expand_path(__FILE__), last_response.headers["X-Sendfile"]
    end

    test "config.action_dispatch.x_sendfile_header is sent to Rack::Sendfile" do
      make_basic_app do |app|
        app.config.action_dispatch.x_sendfile_header = 'X-Lighttpd-Send-File'
      end

      class ::OmgController < ActionController::Base
        def index
          send_file __FILE__
        end
      end

      get "/"
      assert_equal File.expand_path(__FILE__), last_response.headers["X-Lighttpd-Send-File"]
    end

    # remote_ip tests
    test "remote_ip works" do
      make_basic_app
      assert_equal "1.1.1.1", remote_ip("REMOTE_ADDR" => "1.1.1.1")
    end

    test "checks IP spoofing by default" do
      make_basic_app
      assert_raises(ActionDispatch::RemoteIp::IpSpoofAttackError) do
        remote_ip("HTTP_X_FORWARDED_FOR" => "1.1.1.1", "HTTP_CLIENT_IP" => "1.1.1.2")
      end
    end

    test "can disable IP spoofing check" do
      make_basic_app do |app|
        app.config.action_dispatch.ip_spoofing_check = false
      end

      assert_nothing_raised(ActionDispatch::RemoteIp::IpSpoofAttackError) do
        assert_equal "1.1.1.2", remote_ip("HTTP_X_FORWARDED_FOR" => "1.1.1.1", "HTTP_CLIENT_IP" => "1.1.1.2")
      end
    end

    test "the user can set trusted proxies" do
      make_basic_app do |app|
        app.config.action_dispatch.trusted_proxies = /^4\.2\.42\.42$/
      end

      assert_equal "1.1.1.1", remote_ip("REMOTE_ADDR" => "4.2.42.42,1.1.1.1")
    end

    test "show exceptions middleware filter backtrace before logging" do
      my_middleware = Struct.new(:app) do
        def call(env)
          raise "Failure"
        end
      end

      make_basic_app do |app|
        app.config.middleware.use my_middleware
      end

      stringio = StringIO.new
      Rails.logger = Logger.new(stringio)

      env = Rack::MockRequest.env_for("/")
      Rails.application.call(env)
      assert_no_match(/action_dispatch/, stringio.string)
    end

    # show_exceptions test
    test "unspecified route when set action_dispatch.show_exceptions to false" do
      make_basic_app do |app|
        app.config.action_dispatch.show_exceptions = false
      end

      assert_raise(ActionController::RoutingError) do
        get '/foo'
      end
    end

    test "unspecified route when set action_dispatch.show_exceptions to true" do
      make_basic_app do |app|
        app.config.action_dispatch.show_exceptions = true
      end

      assert_nothing_raised(ActionController::RoutingError) do
        get '/foo'
      end
    end

    private

      def boot!
        require "#{app_path}/config/environment"
      end

      def middleware
        AppTemplate::Application.middleware.map(&:klass).map(&:name)
      end

      def remote_ip(env = {})
        remote_ip = nil
        env = Rack::MockRequest.env_for("/").merge(env).merge!(
          'action_dispatch.show_exceptions' => false,
          'action_dispatch.secret_token' => 'b3c631c314c0bbca50c1b2843150fe33'
        )

        endpoint = Proc.new do |e|
          remote_ip = ActionDispatch::Request.new(e).remote_ip
          [200, {}, ["Hello"]]
        end

        Rails.application.middleware.build(endpoint).call(env)
        remote_ip
      end
  end
end
