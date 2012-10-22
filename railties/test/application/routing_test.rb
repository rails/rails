require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class RoutingTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
      boot_rails
    end

    def teardown
      teardown_app
    end

    test "rails/info/routes in development" do
      app("development")
      get "/rails/info/routes"
      assert_equal 200, last_response.status
    end

    test "rails/info/properties in development" do
      app("development")
      get "/rails/info/properties"
      assert_equal 200, last_response.status
    end

    test "rails/info/routes in production" do
      app("production")
      get "/rails/info/routes"
      assert_equal 404, last_response.status
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

    test "simple controller with helper" do
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render inline: "<%= foo_or_bar? %>"
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
        AppTemplate::Application.routes.draw do
          get ':controller(/:action)'
        end
      RUBY

      get '/foo'
      assert_equal 'bar', last_response.body
    end

    test "mount rack app" do
      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          mount lambda { |env| [200, {}, [env["PATH_INFO"]]] }, at: "/blog"
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
            render text: "foo"
          end
        end
      RUBY

      controller :bar, <<-RUBY
        class BarController < ActionController::Base
          def index
            render text: "bar"
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          get ':controller(/:action)'
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
            render text: "foo"
          end
        end
      RUBY

      controller 'admin/foo', <<-RUBY
        module Admin
          class FooController < ApplicationController
            def index
              render text: "admin::foo"
            end
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          get 'admin/foo', to: 'admin/foo#index'
          get 'foo', to: 'foo#index'
        end
      RUBY

      get '/foo'
      assert_equal 'foo', last_response.body

      get '/admin/foo'
      assert_equal 'admin::foo', last_response.body
    end

    test "routes appending blocks" do
      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          get ':controller/:action'
        end
      RUBY

      add_to_config <<-R
        routes.append do
          get '/win' => lambda { |e| [200, {'Content-Type'=>'text/plain'}, ['WIN']] }
        end
      R

      app 'development'

      get '/win'
      assert_equal 'WIN', last_response.body

      app_file 'config/routes.rb', <<-R
        AppTemplate::Application.routes.draw do
          get 'lol' => 'hello#index'
        end
      R

      get '/win'
      assert_equal 'WIN', last_response.body
    end

    {"development" => "baz", "production" => "bar"}.each do |mode, expected|
      test "reloads routes when configuration is changed in #{mode}" do
        controller :foo, <<-RUBY
          class FooController < ApplicationController
            def bar
              render text: "bar"
            end

            def baz
              render text: "baz"
            end
          end
        RUBY

        app_file 'config/routes.rb', <<-RUBY
          AppTemplate::Application.routes.draw do
            get 'foo', to: 'foo#bar'
          end
        RUBY

        app(mode)

        get '/foo'
        assert_equal 'bar', last_response.body

        app_file 'config/routes.rb', <<-RUBY
          AppTemplate::Application.routes.draw do
            get 'foo', to: 'foo#baz'
          end
        RUBY

        sleep 0.1

        get '/foo'
        assert_equal expected, last_response.body
      end
    end

    test 'routes are loaded just after initialization' do
      require "#{app_path}/config/application"

      # Create the rack app just inside after initialize callback
      ActiveSupport.on_load(:after_initialize) do
        ::InitializeRackApp = lambda { |env| [200, {}, ["InitializeRackApp"]] }
      end

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          get 'foo', to: ::InitializeRackApp
        end
      RUBY

      get '/foo'
      assert_equal "InitializeRackApp", last_response.body
    end

    test 'reload_routes! is part of Rails.application API' do
      app("development")
      assert_nothing_raised do
        Rails.application.reload_routes!
      end
    end

    test 'resource routing with irregular inflection' do
      app_file 'config/initializers/inflection.rb', <<-RUBY
        ActiveSupport::Inflector.inflections do |inflect|
          inflect.irregular 'yazi', 'yazilar'
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          resources :yazilar
        end
      RUBY

      controller 'yazilar', <<-RUBY
        class YazilarController < ApplicationController
          def index
            render text: 'yazilar#index'
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
