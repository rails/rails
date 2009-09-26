require "isolation/abstract_unit"
require "rails"
require 'action_dispatch'

module ApplicationTests
  class LoadTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    test "rails app is present" do
      assert File.exist?(app_path("config"))
    end

    test "running Rails::Application.load on the path returns a (vaguely) useful application" do
      app_file "config.ru", <<-CONFIG
        require File.dirname(__FILE__) + '/config/environment'
        run ActionController::Dispatcher.new
      CONFIG

      @app = ActionDispatch::Utils.parse_config("#{app_path}/config.ru")
      assert_welcome get("/")
    end

    test "config.ru is used" do
      app_file "config.ru", <<-CONFIG
        class MyMiddleware
          def initialize(app)
            @app = app
          end

          def call(env)
            status, headers, body = @app.call(env)
            headers["Config-Ru-Test"] = "TESTING"
            [status, headers, body]
          end
        end

        use MyMiddleware
        run proc {|env| [200, {"Content-Type" => "text/html"}, ["VICTORY"]] }
      CONFIG

      @app = ActionDispatch::Utils.parse_config("#{app_path}/config.ru")

      assert_body    "VICTORY", get("/omg")
      assert_header  "Config-Ru-Test", "TESTING", get("/omg")
    end

    test "arbitrary.rb can be used as a config" do
      app_file "myapp.rb", <<-CONFIG
        Myapp = proc {|env| [200, {"Content-Type" => "text/html"}, ["OMG ROBOTS"]] }
      CONFIG

      @app = ActionDispatch::Utils.parse_config("#{app_path}/myapp.rb")

      assert_body "OMG ROBOTS", get("/omg")
    end
  end
end
