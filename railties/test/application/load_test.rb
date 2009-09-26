require "isolation/abstract_unit"
require "rails"
require "rack"

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
      @app = Rails::Application.load app_path
      assert_welcome get("/")
    end

    test "setting the map_path of the application" do
      controller "says", <<-CONTROLLER
        class SaysController < ActionController::Base
          def index ; render :text => "MOO!" ; end
        end
      CONTROLLER

      @app = Rails::Application.load app_path, :path => "/the/cow"

      assert_missing get("/")
      assert_welcome get("/the/cow")
      assert_body    "MOO!", get("/the/cow/says")
    end

    test "url generation with a base path" do
      controller "generatin", <<-CONTROLLER
        class GeneratinController < ActionController::Base
          def index ; render :text => url_for(:action => "index", :only_path => true) ; end
        end
      CONTROLLER

      @app = Rails::Application.load app_path, :path => "/base"

      assert_body "/base/generatin", get("/base/generatin")
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
      
      @app = Rails::Application.load app_path, :config => "config.ru"

      assert_body    "VICTORY", get("/omg")
      assert_header  "Config-Ru-Test", "TESTING", get("/omg")
    end
    
    test "arbitrary.rb can be used as a config" do
      app_file "myapp.rb", <<-CONFIG
        Myapp = proc {|env| [200, {"Content-Type" => "text/html"}, ["OMG ROBOTS"]] }
      CONFIG
      
      @app = Rails::Application.load app_path, :config => "myapp.rb"
      
      assert_body "OMG ROBOTS", get("/omg")
    end

    %w(cache pids sessions sockets).each do |dir|
      test "creating tmp/#{dir} if it does not exist" do
        FileUtils.rm_r(app_path("tmp/#{dir}"))
        Rails::Application.load app_path
        assert File.exist?(app_path("tmp/#{dir}"))
      end
    end

    test "LogTailer middleware is present when not detached" do
      
    end

    test "Debugger middleware is present when using debugger option" do
      
    end
  end
end