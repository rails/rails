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
        AppTemplate::Application.routes.draw do
          match "/engine_route" => "application_generating#engine_route"
          match "/engine_route_in_view" => "application_generating#engine_route_in_view"
          match "/url_for_engine_route" => "application_generating#url_for_engine_route"
          match "/polymorphic_route" => "application_generating#polymorphic_route"
          scope "/:user", :user => "anonymous" do
            mount Blog::Engine => "/blog"
          end
          root :to => 'main#index'
        end
      RUBY

      @plugin.write "app/models/blog/post.rb", <<-RUBY
        module Blog
          class Post
            extend ActiveModel::Naming

            def id
              44
            end

            def to_param
              id.to_s
            end

            def new_record?
              false
            end
          end
        end
      RUBY

      @plugin.write "lib/blog.rb", <<-RUBY
        module Blog
          class Engine < ::Rails::Engine
            isolate_namespace(Blog)
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Blog::Engine.routes.draw do
          resources :posts
          match '/generate_application_route', :to => 'posts#generate_application_route'
          match '/application_route_in_view', :to => 'posts#application_route_in_view'
        end
      RUBY

      @plugin.write "app/controllers/blog/posts_controller.rb", <<-RUBY
        module Blog
          class PostsController < ActionController::Base
            def index
              render :text => blog.post_path(1)
            end

            def generate_application_route
              path = main_app.url_for(:controller => "/main",
                                 :action => "index",
                                 :only_path => true)
              render :text => path
            end

            def application_route_in_view
              render :inline => "<%= main_app.root_path %>"
            end
          end
        end
      RUBY

      app_file "app/controllers/application_generating_controller.rb", <<-RUBY
        class ApplicationGeneratingController < ActionController::Base
          def engine_route
            render :text => blog.posts_path
          end

          def engine_route_in_view
            render :inline => "<%= blog.posts_path %>"
          end

          def url_for_engine_route
            render :text => blog.url_for(:controller => "blog/posts", :action => "index", :user => "john", :only_path => true)
          end

          def polymorphic_route
            render :text => polymorphic_url([blog, Blog::Post.new])
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
      reset_script_name!

      # test polymorphic routes
      get "/polymorphic_route"
      assert_equal "http://example.org/anonymous/blog/posts/44", last_response.body
    end
  end
end

