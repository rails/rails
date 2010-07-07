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
          match "/url_for_engine_route" => "application_generating#url_for_engine_route"
          scope "/:user", :user => "anonymous" do
            mount Blog::Engine => "/blog"
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
          end
        end
      RUBY

      @plugin.write "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
          include Blog::Engine.routes.url_helpers

          def index
            render :text => post_path(1)
          end

          def generate_application_route
            path = url_for( :routes => Rails.application.routes,
                            :controller => "main",
                            :action => "index",
                            :only_path => true)
            render :text => path
          end
        end
      RUBY

      app_file "app/controllers/application_generating_controller.rb", <<-RUBY
        class ApplicationGeneratingController < ActionController::Base
          include Blog::Engine.routes.url_helpers

          def engine_route
            render :text => posts_path
          end

          def url_for_engine_route
            render :text => url_for(:controller => "posts", :action => "index", :user => "john", :only_path => true)
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

    test "routes generation in engine and application" do
      # test generating engine's route from engine
      get "/john/blog/posts"
      assert_equal "/john/blog/posts/1", last_response.body

      # test generating engine's route from application
      get "/engine_route"
      assert_equal "/anonymous/blog/posts", last_response.body
      get "/url_for_engine_route"
      assert_equal "/john/blog/posts", last_response.body

      # test generating application's route from engine
      get "/someone/blog/generate_application_route"
      assert_equal "/", last_response.body
      get "/someone/blog/generate_application_route", {}, "SCRIPT_NAME" => "/foo"
      assert_equal "/foo/", last_response.body
    end
  end
end

