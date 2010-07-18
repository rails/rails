require 'isolation/abstract_unit'

module ApplicationTests
  class ApplicationRoutingTest < Test::Unit::TestCase
     require 'rack/test'
     include Rack::Test::Methods
     include ActiveSupport::Testing::Isolation

    def setup
      build_app

      add_to_config("config.action_dispatch.show_exceptions = false")

      @plugin = engine "blog"

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match "/engine_route" => "application_generating#engine_route"
          match "/engine_route_in_view" => "application_generating#engine_route_in_view"
          match "/url_for_engine_route" => "application_generating#url_for_engine_route"
          scope "/:user", :user => "anonymous" do
            mount Blog::Engine => "/blog", :as => "blog_engine"
          end
          root :to => 'main#index'
        end
      RUBY

      @plugin.write "lib/blog.rb", <<-RUBY
        module Blog
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      app_file "config/initializers/bla.rb", <<-RUBY
        Blog::Engine.eager_load!
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Blog::Engine.routes.draw do
          resources :posts do
            get :generate_application_route
            get :application_route_in_view
          end
        end
      RUBY

      @plugin.write "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
          def index
            render :text => blog_engine.post_path(1)
          end

          def generate_application_route
            path = app.url_for(:controller => "main",
                               :action => "index",
                               :only_path => true)
            render :text => path
          end

          def application_route_in_view
            render :inline => "<%= app.root_path %>"
          end
        end
      RUBY

      app_file "app/controllers/application_generating_controller.rb", <<-RUBY
        class ApplicationGeneratingController < ActionController::Base
          def engine_route
            render :text => blog_engine.posts_path
          end

          def engine_route_in_view
            render :inline => "<%= blog_engine.posts_path %>"
          end

          def url_for_engine_route
            render :text => blog_engine.url_for(:controller => "posts", :action => "index", :user => "john", :only_path => true)
          end
        end
      RUBY

      boot_rails
    end

    def app
      @app ||= begin
        require "#{app_path}/config/environment"
        Rails.application
      end
    end

    def reset_script_name!
      Rails.application.routes.default_url_options = {}
    end
    
    def script_name(script_name)
      Rails.application.routes.default_url_options = {:script_name => script_name}
    end

    test "routes generation in engine and application" do
      # test generating engine's route from engine
      get "/john/blog/posts"
      assert_equal "/john/blog/posts/1", last_response.body

      # test generating engine's route from engine with default_url_options
      script_name "/foo"
      get "/john/blog/posts", {}, 'SCRIPT_NAME' => "/foo"
      assert_equal "/foo/john/blog/posts/1", last_response.body
      reset_script_name!

      # test generating engine's route from application
      get "/engine_route"
      assert_equal "/anonymous/blog/posts", last_response.body

      get "/engine_route_in_view"
      assert_equal "/anonymous/blog/posts", last_response.body

      get "/url_for_engine_route"
      assert_equal "/john/blog/posts", last_response.body

      # test generating engine's route from application with default_url_options
      script_name "/foo"
      get "/engine_route", {}, 'SCRIPT_NAME' => "/foo"
      assert_equal "/foo/anonymous/blog/posts", last_response.body

      script_name "/foo"
      get "/url_for_engine_route", {}, 'SCRIPT_NAME' => "/foo"
      assert_equal "/foo/john/blog/posts", last_response.body
      reset_script_name!

      # test generating application's route from engine
      get "/someone/blog/generate_application_route"
      assert_equal "/", last_response.body

      get "/somone/blog/application_route_in_view"
      assert_equal "/", last_response.body

      # test generating application's route from engine with default_url_options
      script_name "/foo"
      get "/someone/blog/generate_application_route", {}, 'SCRIPT_NAME' => '/foo'
      assert_equal "/foo/", last_response.body
    end
  end
end

