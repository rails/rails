require "isolation/abstract_unit"

module ApplicationTests
  class MiddlewareTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "default middleware stack" do
      add_to_config "config.active_record.migration_error = :page_load"

      boot!

      assert_equal [
        "Rack::Sendfile",
        "ActionDispatch::Static",
        "ActionDispatch::Executor",
        "ActiveSupport::Cache::Strategy::LocalCache",
        "Rack::Runtime",
        "Rack::MethodOverride",
        "ActionDispatch::RequestId",
        "Rails::Rack::Logger", # must come after Rack::MethodOverride to properly log overridden methods
        "ActionDispatch::ShowExceptions",
        "ActionDispatch::DebugExceptions",
        "ActionDispatch::RemoteIp",
        "ActionDispatch::Reloader",
        "ActionDispatch::Callbacks",
        "ActiveRecord::Migration::CheckPending",
        "ActionDispatch::Cookies",
        "ActionDispatch::Session::CookieStore",
        "ActionDispatch::Flash",
        "Rack::Head",
        "Rack::ConditionalGet",
        "Rack::ETag"
      ], middleware
    end

    test "api middleware stack" do
      add_to_config "config.api_only = true"

      boot!

      assert_equal [
        "Rack::Sendfile",
        "ActionDispatch::Static",
        "ActionDispatch::Executor",
        "ActiveSupport::Cache::Strategy::LocalCache",
        "Rack::Runtime",
        "ActionDispatch::RequestId",
        "Rails::Rack::Logger", # must come after Rack::MethodOverride to properly log overridden methods
        "ActionDispatch::ShowExceptions",
        "ActionDispatch::DebugExceptions",
        "ActionDispatch::RemoteIp",
        "ActionDispatch::Reloader",
        "ActionDispatch::Callbacks",
        "Rack::Head",
        "Rack::ConditionalGet",
        "Rack::ETag"
      ], middleware
    end

    test "Rack::Cache is not included by default" do
      boot!

      assert !middleware.include?("Rack::Cache"), "Rack::Cache is not included in the default stack unless you set config.action_dispatch.rack_cache"
    end

    test "Rack::Cache is present when action_dispatch.rack_cache is set" do
      add_to_config "config.action_dispatch.rack_cache = true"

      boot!

      assert middleware.include?("Rack::Cache")
    end

    test "ActiveRecord::Migration::CheckPending is present when active_record.migration_error is set to :page_load" do
      add_to_config "config.active_record.migration_error = :page_load"

      boot!

      assert middleware.include?("ActiveRecord::Migration::CheckPending")
    end

    test "ActionDispatch::SSL is present when force_ssl is set" do
      add_to_config "config.force_ssl = true"
      boot!
      assert middleware.include?("ActionDispatch::SSL")
    end

    test "ActionDispatch::SSL is configured with options when given" do
      add_to_config "config.force_ssl = true"
      add_to_config "config.ssl_options = { host: 'example.com' }"
      boot!

      assert_equal [{ host: "example.com" }], Rails.application.middleware.first.args
    end

    test "removing Active Record omits its middleware" do
      use_frameworks []
      boot!
      assert !middleware.include?("ActiveRecord::Migration::CheckPending")
    end

    test "includes executor" do
      boot!
      assert_includes middleware, "ActionDispatch::Executor"
    end

    test "does not include lock if cache_classes is set and so is eager_load" do
      add_to_config "config.cache_classes = true"
      add_to_config "config.eager_load = true"
      boot!
      assert_not_includes middleware, "Rack::Lock"
    end

    test "does not include lock if allow_concurrency is set to :unsafe" do
      add_to_config "config.allow_concurrency = :unsafe"
      boot!
      assert_not_includes middleware, "Rack::Lock"
    end

    test "includes lock if allow_concurrency is disabled" do
      add_to_config "config.allow_concurrency = false"
      boot!
      assert_includes middleware, "Rack::Lock"
    end

    test "removes static asset server if public_file_server.enabled is disabled" do
      add_to_config "config.public_file_server.enabled = false"
      boot!
      assert !middleware.include?("ActionDispatch::Static")
    end

    test "can delete a middleware from the stack" do
      add_to_config "config.middleware.delete ActionDispatch::Static"
      boot!
      assert !middleware.include?("ActionDispatch::Static")
    end

    test "can delete a middleware from the stack even if insert_before is added after delete" do
      add_to_config "config.middleware.delete Rack::Runtime"
      add_to_config "config.middleware.insert_before(Rack::Runtime, Rack::Config)"
      boot!
      assert middleware.include?("Rack::Config")
      assert_not middleware.include?("Rack::Runtime")
    end

    test "can delete a middleware from the stack even if insert_after is added after delete" do
      add_to_config "config.middleware.delete Rack::Runtime"
      add_to_config "config.middleware.insert_after(Rack::Runtime, Rack::Config)"
      boot!
      assert middleware.include?("Rack::Config")
      assert_not middleware.include?("Rack::Runtime")
    end

    test "includes exceptions middlewares even if action_dispatch.show_exceptions is disabled" do
      add_to_config "config.action_dispatch.show_exceptions = false"
      boot!
      assert middleware.include?("ActionDispatch::ShowExceptions")
      assert middleware.include?("ActionDispatch::DebugExceptions")
    end

    test "removes ActionDispatch::Reloader if cache_classes is true" do
      add_to_config "config.cache_classes = true"
      boot!
      assert !middleware.include?("ActionDispatch::Reloader")
    end

    test "use middleware" do
      use_frameworks []
      add_to_config "config.middleware.use Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.last
    end

    test "insert middleware after" do
      add_to_config "config.middleware.insert_after Rack::Sendfile, Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.second
    end

    test "unshift middleware" do
      add_to_config "config.middleware.unshift Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.first
    end

    test "Rails.cache does not respond to middleware" do
      add_to_config "config.cache_store = :memory_store"
      boot!
      assert_equal "Rack::Runtime", middleware.fourth
    end

    test "Rails.cache does respond to middleware" do
      boot!
      assert_equal "Rack::Runtime", middleware.fifth
    end

    test "insert middleware before" do
      add_to_config "config.middleware.insert_before Rack::Sendfile, Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.first
    end

    test "can't change middleware after it's built" do
      boot!
      assert_raise RuntimeError do
        app.config.middleware.use Rack::Config
      end
    end

    # ConditionalGet + Etag
    test "conditional get + etag middlewares handle http caching based on body" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          if params[:nothing]
            render text: ""
          else
            render text: "OMG"
          end
        end
      end

      etag = "W/" + "c00862d1c6c1cf7c1b49388306e7b3c1".inspect

      get "/"
      assert_equal 200, last_response.status
      assert_equal "OMG", last_response.body
      assert_equal "text/html; charset=utf-8", last_response.headers["Content-Type"]
      assert_equal "max-age=0, private, must-revalidate", last_response.headers["Cache-Control"]
      assert_equal etag, last_response.headers["Etag"]

      get "/", {}, "HTTP_IF_NONE_MATCH" => etag
      assert_equal 304, last_response.status
      assert_equal "", last_response.body
      assert_equal nil, last_response.headers["Content-Type"]
      assert_equal "max-age=0, private, must-revalidate", last_response.headers["Cache-Control"]
      assert_equal etag, last_response.headers["Etag"]

      get "/?nothing=true"
      assert_equal 200, last_response.status
      assert_equal "", last_response.body
      assert_equal "text/html; charset=utf-8", last_response.headers["Content-Type"]
      assert_equal "no-cache", last_response.headers["Cache-Control"]
      assert_equal nil, last_response.headers["Etag"]
    end

    test "ORIGINAL_FULLPATH is passed to env" do
      boot!
      env = ::Rack::MockRequest.env_for("/foo/?something")
      Rails.application.call(env)

      assert_equal "/foo/?something", env["ORIGINAL_FULLPATH"]
    end

    private

      def boot!
        require "#{app_path}/config/environment"
      end

      def middleware
        Rails.application.middleware.map(&:klass).map(&:name)
      end
  end
end
