# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class RoutingTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "rails/welcome in development" do
      app("development")
      get "/"
      assert_equal 200, last_response.status
    end

    test "rails/info in development" do
      app("development")
      get "/rails/info"
      assert_equal 302, last_response.status
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

    test "/rails/info routes are accessible with globbing route present" do
      app("development")

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '*foo', to: 'foo#index'
        end
      RUBY

      get "/rails/info"
      assert_equal 302, last_response.status

      get "rails/info/routes"
      assert_equal 200, last_response.status

      get "rails/info/properties"
      assert_equal 200, last_response.status
    end

    test "root takes precedence over internal welcome controller" do
      app("development")

      assert_welcome get("/")

      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render plain: "foo"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "foo#index"
        end
      RUBY

      get "/"
      assert_equal "foo", last_response.body
    end

    test "appended root takes precedence over internal welcome controller" do
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render plain: "foo"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
        end

        Rails.application.routes.append do
          get "/", to: "foo#index"
        end
      RUBY

      app("development")
      get "/"

      assert_equal "foo", last_response.body
    end

    test "rails/welcome in production" do
      app("production")
      get("/", {}, "HTTPS" => "on")
      assert_equal 404, last_response.status
    end

    test "rails/info in production" do
      app("production")
      get("/rails/info", {}, "HTTPS" => "on")
      assert_equal 404, last_response.status
    end

    test "rails/info/routes in production" do
      app("production")
      get("/rails/info/routes", {}, "HTTPS" => "on")
      assert_equal 404, last_response.status
    end

    test "rails/info/properties in production" do
      app("production")
      get("/rails/info/properties", {}, "HTTPS" => "on")
      assert_equal 404, last_response.status
    end

    test "rails/health in production" do
      app("production")

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get "up" => "rails/health#show", as: :rails_health_check
        end
      RUBY

      get("/up", {}, "HTTPS" => "on")
      assert_equal 200, last_response.status
    end

    test "simple controller" do
      simple_controller

      app "development"

      get "/foo"
      assert_equal "foo", last_response.body
    end

    test "simple controller with helper" do
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render inline: "<%= foo_or_bar? %>"
          end
        end
      RUBY

      app_file "app/helpers/bar_helper.rb", <<-RUBY
        module BarHelper
          def foo_or_bar?
            "bar"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get ':controller(/:action)'
        end
      RUBY

      app "development"

      get "/foo"
      assert_equal "bar", last_response.body
    end

    test "mount rack app" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount lambda { |env| [200, {}, [env["PATH_INFO"]]] }, at: "/blog"
          # The line below is required because mount sometimes
          # fails when a resource route is added.
          resource :user
        end
      RUBY

      app "development"

      get "/blog/archives"
      assert_equal "/archives", last_response.body
    end

    test "mount named rack app" do
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render plain: my_blog_path
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount lambda { |env| [200, {}, [env["PATH_INFO"]]] }, at: "/blog", as: "my_blog"
          get '/foo' => 'foo#index'
        end
      RUBY

      app "development"

      get "/foo"
      assert_equal "/blog", last_response.body
    end

    test "multiple controllers" do
      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render plain: "foo"
          end
        end
      RUBY

      controller :bar, <<-RUBY
        class BarController < ActionController::Base
          def index
            render plain: "bar"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get ':controller(/:action)'
        end
      RUBY

      app "development"

      get "/foo"
      assert_equal "foo", last_response.body

      get "/bar"
      assert_equal "bar", last_response.body
    end

    test "nested controller" do
      controller "foo", <<-RUBY
        class FooController < ApplicationController
          def index
            render plain: "foo"
          end
        end
      RUBY

      controller "admin/foo", <<-RUBY
        module Admin
          class FooController < ApplicationController
            def index
              render plain: "admin::foo"
            end
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'admin/foo', to: 'admin/foo#index'
          get 'foo', to: 'foo#index'
        end
      RUBY

      app "development"

      get "/foo"
      assert_equal "foo", last_response.body

      get "/admin/foo"
      assert_equal "admin::foo", last_response.body
    end

    test "routes appending blocks" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get ':controller/:action'
        end
      RUBY

      add_to_config <<-R
        routes.append do
          get '/win' => lambda { |e| [200, {'Content-Type'=>'text/plain'}, ['WIN']] }
        end
      R

      app "development"

      get "/win"
      assert_equal "WIN", last_response.body

      app_file "config/routes.rb", <<-R
        Rails.application.routes.draw do
          get 'lol' => 'hello#index'
        end
      R

      get "/win"
      assert_equal "WIN", last_response.body
    end

    test "routes appending blocks after reload" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get ':controller/:action'
        end
      RUBY

      add_to_config <<-R
        config.before_eager_load do |app|
          app.reload_routes!
        end

        config.after_initialize do |app|
          app.routes.append do
            get '/win' => lambda { |e| [200, {'Content-Type'=>'text/plain'}, ['WIN']] }
          end
        end
      R

      app "production"

      get "/win"
      assert_equal "WIN", last_response.body
    end

    test "routes drawing from config/routes" do
      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          draw :external
        end
      RUBY

      app_file "config/routes/external.rb", <<-RUBY
        get ':controller/:action'
      RUBY

      controller :success, <<-RUBY
        class SuccessController < ActionController::Base
          def index
            render plain: "success!"
          end
        end
      RUBY

      app "development"
      get "/success/index"
      assert_equal "success!", last_response.body
    end

    {
      "development" => ["baz", "http://www.apple.com", "/dashboard"],
      "production"  => ["bar", "http://www.microsoft.com", "/profile"]
    }.each do |mode, (expected_action, expected_url, expected_mapping)|
      test "reloads routes when configuration is changed in #{mode}" do
        controller :foo, <<-RUBY
          class FooController < ApplicationController
            def bar
              render plain: "bar"
            end

            def baz
              render plain: "baz"
            end

            def custom
              render plain: custom_url
            end

            def mapping
              render plain: url_for(User.new)
            end
          end
        RUBY

        app_file "app/models/user.rb", <<-RUBY
          class User
            extend ActiveModel::Naming
            include ActiveModel::Conversion

            def self.model_name
              @_model_name ||= ActiveModel::Name.new(self.class, nil, "User")
            end

            def persisted?
              false
            end
          end
        RUBY

        app_file "config/routes.rb", <<-RUBY
          Rails.application.routes.draw do
            draw :external
            get 'custom', to: 'foo#custom'
            get 'mapping', to: 'foo#mapping'

            direct(:custom) { "http://www.microsoft.com" }
            resolve("User") { "/profile" }
          end
        RUBY

        app_file "config/routes/external.rb", <<-RUBY
          get 'foo', to: 'foo#bar'
        RUBY

        app(mode)

        https = (mode == "production" ? "on" : "off")

        get("/foo", {}, "HTTPS" => https)
        assert_equal "bar", last_response.body

        get("/custom", {}, "HTTPS" => https)
        assert_equal "http://www.microsoft.com", last_response.body

        get("/mapping", {}, "HTTPS" => https)
        assert_equal "/profile", last_response.body

        app_file "config/routes.rb", <<-RUBY
          Rails.application.routes.draw do
            draw :another_external
            get 'custom', to: 'foo#custom'
            get 'mapping', to: 'foo#mapping'

            direct(:custom) { "http://www.apple.com" }
            resolve("User") { "/dashboard" }
          end
        RUBY

        app_file "config/routes/another_external.rb", <<-RUBY
          get 'foo', to: 'foo#baz'
        RUBY

        sleep 0.1

        get("/foo", {}, "HTTPS" => https)
        assert_equal expected_action, last_response.body

        get("/custom", {}, "HTTPS" => https)
        assert_equal expected_url, last_response.body

        get("/mapping", {}, "HTTPS" => https)
        assert_equal expected_mapping, last_response.body
      end
    end

    test "routes are loaded just after initialization" do
      require "#{app_path}/config/application"

      # Create the rack app just inside after initialize callback
      ActiveSupport.on_load(:after_initialize) do
        ::InitializeRackApp = lambda { |env| [200, {}, ["InitializeRackApp"]] }
      end

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'foo', to: ::InitializeRackApp
        end
      RUBY

      get "/foo"
      assert_equal "InitializeRackApp", last_response.body
    end

    test "reload_routes! is part of Rails.application API" do
      app("development")
      assert_nothing_raised do
        Rails.application.reload_routes!
      end
    end

    def test_root_path
      app("development")

      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render plain: "foo"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'foo', :to => 'foo#index'
          root :to => 'foo#index'
        end
      RUBY

      remove_file "public/index.html"

      get "/"
      assert_equal "foo", last_response.body
    end

    test "routes are added and removed when reloading" do
      app("development")

      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render plain: "foo"
          end

          def custom
            render plain: custom_url
          end

          def mapping
            render plain: url_for(User.new)
          end
        end
      RUBY

      controller :bar, <<-RUBY
        class BarController < ApplicationController
          def index
            render plain: "bar"
          end
        end
      RUBY

      app_file "app/models/user.rb", <<-RUBY
        class User
          extend ActiveModel::Naming
          include ActiveModel::Conversion

          def self.model_name
            @_model_name ||= ActiveModel::Name.new(self.class, nil, "User")
          end

          def persisted?
            false
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'foo', to: 'foo#index'
        end
      RUBY

      get "/foo"
      assert_equal "foo", last_response.body
      assert_equal "/foo", Rails.application.routes.url_helpers.foo_path

      get "/bar"
      assert_equal 404, last_response.status
      assert_raises NoMethodError do
        Rails.application.routes.url_helpers.bar_path
      end

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'foo', to: 'foo#index'
          get 'bar', to: 'bar#index'

          get 'custom', to: 'foo#custom'
          direct(:custom) { 'http://www.apple.com' }

          get 'mapping', to: 'foo#mapping'
          resolve('User') { '/profile' }
        end
      RUBY

      Rails.application.reload_routes!

      get "/foo"
      assert_equal "foo", last_response.body
      assert_equal "/foo", Rails.application.routes.url_helpers.foo_path

      get "/bar"
      assert_equal "bar", last_response.body
      assert_equal "/bar", Rails.application.routes.url_helpers.bar_path

      get "/custom"
      assert_equal "http://www.apple.com", last_response.body
      assert_equal "http://www.apple.com", Rails.application.routes.url_helpers.custom_url

      get "/mapping"
      assert_equal "/profile", last_response.body
      assert_equal "/profile", Rails.application.routes.url_helpers.polymorphic_path(User.new)

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'foo', to: 'foo#index'
        end
      RUBY

      Rails.application.reload_routes!

      get "/foo"
      assert_equal "foo", last_response.body
      assert_equal "/foo", Rails.application.routes.url_helpers.foo_path

      get "/bar"
      assert_equal 404, last_response.status
      assert_raises NoMethodError do
        Rails.application.routes.url_helpers.bar_path
      end

      get "/custom"
      assert_equal 404, last_response.status
      assert_raises NoMethodError do
        Rails.application.routes.url_helpers.custom_url
      end

      get "/mapping"
      assert_equal 404, last_response.status
      assert_raises NoMethodError do
        Rails.application.routes.url_helpers.polymorphic_path(User.new)
      end
    end

    test "named routes are cleared when reloading" do
      app("development")

      controller :foo, <<-RUBY
        class FooController < ApplicationController
          def index
            render plain: "foo"
          end
        end
      RUBY

      controller :bar, <<-RUBY
        class BarController < ApplicationController
          def index
            render plain: "bar"
          end
        end
      RUBY

      app_file "app/models/user.rb", <<-RUBY
        class User
          extend ActiveModel::Naming
          include ActiveModel::Conversion

          def self.model_name
            @_model_name ||= ActiveModel::Name.new(self.class, nil, "User")
          end

          def persisted?
            false
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get ':locale/foo', to: 'foo#index', as: 'foo'
          get 'users', to: 'foo#users', as: 'users'
          direct(:microsoft) { 'http://www.microsoft.com' }
          resolve('User') { '/profile' }
        end
      RUBY

      get "/en/foo"
      assert_equal "foo", last_response.body
      assert_equal "/en/foo", Rails.application.routes.url_helpers.foo_path(locale: "en")
      assert_equal "http://www.microsoft.com", Rails.application.routes.url_helpers.microsoft_url
      assert_equal "/profile", Rails.application.routes.url_helpers.polymorphic_path(User.new)

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get ':locale/bar', to: 'bar#index', as: 'foo'
          get 'users', to: 'foo#users', as: 'users'
          direct(:apple) { 'http://www.apple.com' }
        end
      RUBY

      Rails.application.reload_routes!

      get "/en/foo"
      assert_equal 404, last_response.status

      get "/en/bar"
      assert_equal "bar", last_response.body
      assert_equal "/en/bar", Rails.application.routes.url_helpers.foo_path(locale: "en")
      assert_equal "http://www.apple.com", Rails.application.routes.url_helpers.apple_url
      assert_equal "/users", Rails.application.routes.url_helpers.polymorphic_path(User.new)

      assert_raises NoMethodError do
        Rails.application.routes.url_helpers.microsoft_url
      end
    end

    test "resource routing with irregular inflection" do
      app("development")

      app_file "config/initializers/inflection.rb", <<-RUBY
        ActiveSupport::Inflector.inflections do |inflect|
          inflect.irregular 'yazi', 'yazilar'
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          resources :yazilar
        end
      RUBY

      controller "yazilar", <<-RUBY
        class YazilarController < ApplicationController
          def index
            render plain: 'yazilar#index'
          end
        end
      RUBY

      get "/yazilars"
      assert_equal 404, last_response.status

      get "/yazilar"
      assert_equal 200, last_response.status
    end

    test "reloading routes removes methods and doesn't undefine them" do
      app("development")

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/url', to: 'url#index'
        end
      RUBY

      app_file "app/models/url_helpers.rb", <<-RUBY
        module UrlHelpers
          def foo_path
            "/foo"
          end
        end
      RUBY

      app_file "app/models/context.rb", <<-RUBY
        class Context
          include UrlHelpers
          include Rails.application.routes.url_helpers
        end
      RUBY

      controller "url", <<-RUBY
        class UrlController < ApplicationController
          def index
            context = Context.new
            render plain: context.foo_path
          end
        end
      RUBY

      get "/url"
      assert_equal "/foo", last_response.body

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/url', to: 'url#index'
          get '/bar', to: 'foo#index', as: 'foo'
        end
      RUBY

      Rails.application.reload_routes!

      get "/url"
      assert_equal "/bar", last_response.body

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/url', to: 'url#index'
        end
      RUBY

      Rails.application.reload_routes!

      get "/url"
      assert_equal "/foo", last_response.body
    end

    test "request to rails/welcome for api_only app is successful" do
      add_to_config <<-RUBY
        config.api_only = true
        config.action_dispatch.show_exceptions = :none
        config.action_controller.allow_forgery_protection = true
      RUBY

      app "development"

      get "/"
      assert_equal 200, last_response.status
    end

    test "request to rails/welcome is successful when default_protect_from_forgery is false" do
      add_to_config <<-RUBY
        config.action_dispatch.show_exceptions = :none
        config.action_controller.default_protect_from_forgery = false
      RUBY

      app "development"

      get "/"
      assert_equal 200, last_response.status
    end
  end
end
