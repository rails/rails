# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ApplicationRoutingTest < ActiveSupport::TestCase
    require "rack/test"
    include Rack::Test::Methods
    include ActiveSupport::Testing::Isolation

    def setup
      build_app

      add_to_config("config.action_dispatch.show_exceptions = :none")

      @simple_plugin = engine "weblog"
      @plugin = engine "blog"
      @metrics_plugin = engine "metrics"

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount Weblog::Engine, :at => '/', :as => 'weblog'
          resources :posts
          get "/engine_route" => "application_generating#engine_route"
          get "/engine_route_in_view" => "application_generating#engine_route_in_view"
          get "/weblog_engine_route" => "application_generating#weblog_engine_route"
          get "/weblog_through_metric_engine_route" => "application_generating#weblog_through_metric_engine_route"
          get "/weblog_engine_route_in_view" => "application_generating#weblog_engine_route_in_view"
          get "/url_for_engine_route" => "application_generating#url_for_engine_route"
          get "/polymorphic_route" => "application_generating#polymorphic_route"
          get "/application_polymorphic_path" => "application_generating#application_polymorphic_path"
          scope "/:user", :user => "anonymous" do
            mount Blog::Engine => "/blog"
          end
          mount Metrics::Engine => "/metrics"
          root :to => 'main#index'
        end
      RUBY

      @simple_plugin.write "lib/weblog.rb", <<-RUBY
        module Weblog
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      @simple_plugin.write "config/routes.rb", <<-RUBY
        Weblog::Engine.routes.draw do
          get '/weblog' => "weblogs#index", as: 'weblogs'
        end
      RUBY

      @simple_plugin.write "app/controllers/weblogs_controller.rb", <<-RUBY
        class WeblogsController < ActionController::Base
          def index
            render plain: request.url
          end
        end
      RUBY

      @metrics_plugin.write "lib/metrics.rb", <<-RUBY
        module Metrics
          class Engine < ::Rails::Engine
            isolate_namespace(Metrics)
          end
        end
      RUBY

      @metrics_plugin.write "config/routes.rb", <<-RUBY
        Metrics::Engine.routes.draw do
          get '/generate_blog_route', to: 'generating#generate_blog_route'
          get '/generate_blog_route_in_view', to: 'generating#generate_blog_route_in_view'
        end
      RUBY

      @metrics_plugin.write "app/controllers/metrics/generating_controller.rb", <<-RUBY
        module Metrics
          class GeneratingController < ActionController::Base
            def generate_blog_route
              render plain: blog.post_path(1)
            end

            def generate_blog_route_in_view
              render inline: "<%= blog.post_path(1) -%>"
            end
          end
        end
      RUBY

      @plugin.write "app/models/blog/post.rb", <<-RUBY
        module Blog
          class Post
            include ActiveModel::Model

            def id
              44
            end

            def persisted?
              true
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
          get '/different_context', to: 'posts#different_context'
          get '/generate_application_route', to: 'posts#generate_application_route'
          get '/application_route_in_view', to: 'posts#application_route_in_view'
          get '/engine_polymorphic_path', to: 'posts#engine_polymorphic_path'
          get '/engine_asset_path', to: 'posts#engine_asset_path'
          get '/file_field_with_direct_upload_path', to: 'posts#file_field_with_direct_upload_path'
        end
      RUBY

      @plugin.write "app/controllers/blog/posts_controller.rb", <<-RUBY
        module Blog
          class PostsController < ActionController::Base
            def index
              render plain: blog.post_path(1)
            end

            def different_context
              render plain: blog.post_path(1, user: "ada")
            end

            def generate_application_route
              path = main_app.url_for(controller: "/main",
                                 action: "index",
                                 only_path: true)
              render plain: path
            end

            def application_route_in_view
              render inline: "<%= main_app.root_path %>"
            end

            def engine_polymorphic_path
              render plain: polymorphic_path(Post.new)
            end

            def engine_asset_path
              render inline: "<%= asset_path 'images/foo.png', skip_pipeline: true %>"
            end

            def file_field_with_direct_upload_path
              render inline: "<%= file_field_tag :image, direct_upload: true %>"
            end
          end
        end
      RUBY

      app_file "app/controllers/application_generating_controller.rb", <<-RUBY
        class ApplicationGeneratingController < ActionController::Base
          def engine_route
            render plain: blog.posts_path
          end

          def engine_route_in_view
            render inline: "<%= blog.posts_path %>"
          end

          def weblog_engine_route
            render plain: weblog.weblogs_path
          end

          def weblog_through_metric_engine_route
            # trigger definition of route helper
            weblog.weblogs_path

            render plain: metrics.respond_to?(:weblogs_path)
          end

          def weblog_engine_route_in_view
            render inline: "<%= weblog.weblogs_path %>"
          end

          def url_for_engine_route
            render plain: blog.url_for(controller: "blog/posts", action: "index", user: "john", only_path: true)
          end

          def polymorphic_route
            render plain: polymorphic_url([blog, Blog::Post.new])
          end

          def application_polymorphic_path
            render plain: polymorphic_path(Blog::Post.new)
          end
        end
      RUBY
    end

    def teardown
      teardown_app
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

      # test generating engine route from engine with a different context
      get "/john/blog/different_context"
      assert_equal "/ada/blog/posts/1", last_response.body

      # test generating engine's route from engine with default_url_options
      get "/john/blog/posts", {}, { "SCRIPT_NAME" => "/foo" }
      assert_equal "/foo/john/blog/posts/1", last_response.body

      # test generating engine's route from application
      get "/engine_route"
      assert_equal "/anonymous/blog/posts", last_response.body

      get "/engine_route_in_view"
      assert_equal "/anonymous/blog/posts", last_response.body

      get "/url_for_engine_route"
      assert_equal "/john/blog/posts", last_response.body

      # test generating engine's route from application with default_url_options
      get "/engine_route", {}, { "SCRIPT_NAME" => "/foo" }
      assert_equal "/foo/anonymous/blog/posts", last_response.body

      get "/url_for_engine_route", {}, { "SCRIPT_NAME" => "/foo" }
      assert_equal "/foo/john/blog/posts", last_response.body

      # test generating application's route from engine
      get "/someone/blog/generate_application_route"
      assert_equal "/", last_response.body

      get "/someone/blog/application_route_in_view"
      assert_equal "/", last_response.body

      # test generating engine's route from other engine
      get "/metrics/generate_blog_route"
      assert_equal "/anonymous/blog/posts/1", last_response.body

      get "/metrics/generate_blog_route_in_view"
      assert_equal "/anonymous/blog/posts/1", last_response.body

      # test generating engine's route from other engine with default_url_options
      get "/metrics/generate_blog_route", {}, { "SCRIPT_NAME" => "/foo" }
      assert_equal "/foo/anonymous/blog/posts/1", last_response.body

      get "/metrics/generate_blog_route_in_view", {}, { "SCRIPT_NAME" => "/foo" }
      assert_equal "/foo/anonymous/blog/posts/1", last_response.body

      # test generating application's route from engine with default_url_options
      get "/someone/blog/generate_application_route", {}, { "SCRIPT_NAME" => "/foo" }
      assert_equal "/foo/", last_response.body

      # test polymorphic routes
      get "/polymorphic_route"
      assert_equal "http://example.org/anonymous/blog/posts/44", last_response.body

      # test that correct path is generated for the same polymorphic_path call in an engine
      get "/someone/blog/engine_polymorphic_path"
      assert_equal "/someone/blog/posts/44", last_response.body

      # and in an application
      get "/application_polymorphic_path"
      assert_equal "/posts/44", last_response.body

      # test that asset path will not get script_name when generated in the engine
      get "/someone/blog/engine_asset_path"
      assert_equal "/images/foo.png", last_response.body

      # test that the Active Storage direct upload URL is added to a file field that explicitly requires it within en engine's view code
      get "/someone/blog/file_field_with_direct_upload_path"
      assert_equal "<input type=\"file\" name=\"image\" id=\"image\" data-direct-upload-url=\"http://example.org/rails/active_storage/direct_uploads\" />", last_response.body
    end

    test "route path for controller action when engine is mounted at root" do
      get "/weblog_engine_route"
      assert_equal "/weblog", last_response.body

      get "/weblog_engine_route_in_view"
      assert_equal "/weblog", last_response.body
    end

    test "route helpers from weblog are not accessible through metrics engine" do
      get "/weblog_through_metric_engine_route"
      assert_equal "false", last_response.body
    end
  end
end
