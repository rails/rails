require 'isolation/abstract_unit'

module ApplicationTests
  class RoutingTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      require 'rack/test'
      extend Rack::Test::Methods
    end

    def app(env = "production")
      old_env = ENV["RAILS_ENV"]

      @app ||= begin
        ENV["RAILS_ENV"] = env
        require "#{app_path}/config/environment"
        Rails.application
      end
    ensure
      ENV["RAILS_ENV"] = old_env
    end

    def simple_controller
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render :text => "foo"
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match ':controller(/:action)'
        end
      RUBY
    end

    def teardown
      teardown_app
    end

    test "rails/info/properties in development" do
      app("development")
      get "/rails/info/properties"
      assert_equal 200, last_response.status
    end

    test "rails/info/properties in production" do
      app("production")
      get "/rails/info/properties"
      assert_equal 404, last_response.status
    end

    test "simple controller" do
      simple_controller

      get '/foo'
      assert_equal 'foo', last_response.body
    end

    test "simple controller in production mode returns best standards" do
      simple_controller

      get '/foo'
      assert_equal "IE=Edge,chrome=1", last_response.headers["X-UA-Compatible"]
    end

    test "simple controller in development mode leaves out Chrome" do
      simple_controller
      app("development")

      get "/foo"
      assert_equal "IE=Edge", last_response.headers["X-UA-Compatible"]
    end

    test "simple controller with helper" do
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render :inline => "<%= foo_or_bar? %>"
          end
        end
      RUBY

      app_file 'app/helpers/bar_helper.rb', <<-RUBY
        module BarHelper
          def foo_or_bar?
            "bar"
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match ':controller(/:action)'
        end
      RUBY

      get '/foo'
      assert_equal 'bar', last_response.body
    end

    test "mount rack app" do
      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          mount lambda { |env| [200, {}, [env["PATH_INFO"]]] }, :at => "/blog"
          # The line below is required because mount sometimes
          # fails when a resource route is added.
          resource :user
        end
      RUBY

      get '/blog/archives'
      assert_equal '/archives', last_response.body
    end

    test "multiple controllers" do
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render :text => "foo"
          end
        end
      RUBY

      controller :bar, <<-RUBY
        class BarController < ActionController::Base
          def index
            render :text => "bar"
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match ':controller(/:action)'
        end
      RUBY

      get '/foo'
      assert_equal 'foo', last_response.body

      get '/bar'
      assert_equal 'bar', last_response.body
    end

    test "nested controller" do
      controller 'foo', <<-RUBY
        class FooController < ApplicationController
          def index
            render :text => "foo"
          end
        end
      RUBY

      controller 'admin/foo', <<-RUBY
        module Admin
          class FooController < ApplicationController
            def index
              render :text => "admin::foo"
            end
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match 'admin/foo', :to => 'admin/foo#index'
          match 'foo', :to => 'foo#index'
        end
      RUBY

      get '/foo'
      assert_equal 'foo', last_response.body

      get '/admin/foo'
      assert_equal 'admin::foo', last_response.body
    end

    {"development" => "baz", "production" => "bar"}.each do |mode, expected|
      test "reloads routes when configuration is changed in #{mode}" do
        controller :foo, <<-RUBY
          class FooController < ApplicationController
            def bar
              render :text => "bar"
            end

            def baz
              render :text => "baz"
            end
          end
        RUBY

        app_file 'config/routes.rb', <<-RUBY
          AppTemplate::Application.routes.draw do |map|
            match 'foo', :to => 'foo#bar'
          end
        RUBY

        app(mode)

        get '/foo'
        assert_equal 'bar', last_response.body

        app_file 'config/routes.rb', <<-RUBY
          AppTemplate::Application.routes.draw do |map|
            match 'foo', :to => 'foo#baz'
          end
        RUBY

        sleep 0.1

        get '/foo'
        assert_equal expected, last_response.body
      end
    end

    test 'routes are loaded just after initialization' do
      require "#{app_path}/config/application"

      ActiveSupport.on_load(:after_initialize) do
        ::InitializeRackApp = lambda { |env| [200, {}, ["InitializeRackApp"]] }
      end

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match 'foo', :to => ::InitializeRackApp
        end
      RUBY

      get '/foo'
      assert_equal "InitializeRackApp", last_response.body
    end

    test 'resource routing with irrigular inflection' do
      app_file 'config/initializers/inflection.rb', <<-RUBY
        ActiveSupport::Inflector.inflections do |inflect|
          inflect.irregular 'yazi', 'yazilar'
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          resources :yazilar
        end
      RUBY

      controller 'yazilar', <<-RUBY
        class YazilarController < ApplicationController
          def index
            render :text => 'yazilar#index'
          end
        end
      RUBY

      get '/yazilars'
      assert_equal 404, last_response.status

      get '/yazilar'
      assert_equal 200, last_response.status
    end
  end
end
