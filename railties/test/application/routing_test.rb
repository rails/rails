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

    def app
      @app ||= begin
        require "#{app_path}/config/environment"
        Rails.application
      end
    end

    test "rails/info/properties" do
      get "/rails/info/properties"
      assert_equal 200, last_response.status
    end

    test "simple controller" do
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

      get '/foo'
      assert_equal 'foo', last_response.body
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

    test "reloads routes when configuration is changed" do
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

      get '/foo'
      assert_equal 'bar', last_response.body

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match 'foo', :to => 'foo#baz'
        end
      RUBY

      sleep 0.1

      get '/foo'
      assert_equal 'baz', last_response.body
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
