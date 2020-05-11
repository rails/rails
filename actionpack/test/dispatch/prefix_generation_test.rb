# frozen_string_literal: true

require "abstract_unit"
require "rack/test"
require "rails/engine"

module TestGenerationPrefix
  class Post
    extend ActiveModel::Naming

    def to_param
      "1"
    end

    def self.model_name
      klass = +"Post"
      def klass.name; self end

      ActiveModel::Name.new(klass)
    end

    def to_model; self; end
    def persisted?; true; end
  end

  class WithMountedEngine < ActionDispatch::IntegrationTest
    class BlogEngine < Rails::Engine
      routes.draw do
        get "/posts/:id", to: "inside_engine_generating#show", as: :post
        get "/posts", to: "inside_engine_generating#index", as: :posts
        get "/url_to_application", to: "inside_engine_generating#url_to_application"
        get "/polymorphic_path_for_engine", to: "inside_engine_generating#polymorphic_path_for_engine"
        get "/conflicting_url", to: "inside_engine_generating#conflicting"
        get "/foo", to: "never#invoked", as: :named_helper_that_should_be_invoked_only_in_respond_to_test

        get "/relative_path_root",       to: redirect("")
        get "/relative_path_redirect",   to: redirect("foo")
        get "/relative_option_root",     to: redirect(path: "")
        get "/relative_option_redirect", to: redirect(path: "foo")
        get "/relative_custom_root",     to: redirect { |params, request| "" }
        get "/relative_custom_redirect", to: redirect { |params, request| "foo" }

        get "/absolute_path_root",       to: redirect("/")
        get "/absolute_path_redirect",   to: redirect("/foo")
        get "/absolute_option_root",     to: redirect(path: "/")
        get "/absolute_option_redirect", to: redirect(path: "/foo")
        get "/absolute_custom_root",     to: redirect { |params, request| "/" }
        get "/absolute_custom_redirect", to: redirect { |params, request| "/foo" }
      end
    end

    class RailsApplication < Rails::Engine
      routes.draw do
        scope "/:omg", omg: "awesome" do
          mount BlogEngine => "/blog", :as => "blog_engine"
        end
        get "/posts/:id", to: "outside_engine_generating#post", as: :post
        get "/generate", to: "outside_engine_generating#index"
        get "/polymorphic_path_for_app", to: "outside_engine_generating#polymorphic_path_for_app"
        get "/polymorphic_path_for_engine", to: "outside_engine_generating#polymorphic_path_for_engine"
        get "/polymorphic_with_url_for", to: "outside_engine_generating#polymorphic_with_url_for"
        get "/conflicting_url", to: "outside_engine_generating#conflicting"
        get "/ivar_usage", to: "outside_engine_generating#ivar_usage"
        root to: "outside_engine_generating#index"
      end
    end

    # force draw
    RailsApplication.routes.define_mounted_helper(:main_app)

    class ::InsideEngineGeneratingController < ActionController::Base
      include BlogEngine.routes.url_helpers
      include RailsApplication.routes.mounted_helpers

      def index
        render plain: posts_path
      end

      def show
        render plain: post_path(id: params[:id])
      end

      def url_to_application
        path = main_app.url_for(controller: "outside_engine_generating",
                                action: "index",
                                only_path: true)
        render plain: path
      end

      def polymorphic_path_for_engine
        render plain: polymorphic_path(Post.new)
      end

      def conflicting
        render plain: "engine"
      end
    end

    class ::OutsideEngineGeneratingController < ActionController::Base
      include BlogEngine.routes.mounted_helpers
      include RailsApplication.routes.url_helpers

      def index
        render plain: blog_engine.post_path(id: 1)
      end

      def polymorphic_path_for_engine
        render plain: blog_engine.polymorphic_path(Post.new)
      end

      def polymorphic_path_for_app
        render plain: polymorphic_path(Post.new)
      end

      def polymorphic_with_url_for
        render plain: blog_engine.url_for(Post.new)
      end

      def conflicting
        render plain: "application"
      end

      def ivar_usage
        @blog_engine = "Not the engine route helper"
        render plain: blog_engine.post_path(id: 1)
      end
    end

    module KwObject
      def initialize(kw:)
      end
    end

    class EngineObject
      include KwObject
      include ActionDispatch::Routing::UrlFor
      include BlogEngine.routes.url_helpers
    end

    class AppObject
      include KwObject
      include ActionDispatch::Routing::UrlFor
      include RailsApplication.routes.url_helpers
    end

    def app
      RailsApplication.instance
    end

    attr_reader :engine_object, :app_object

    def setup
      RailsApplication.routes.default_url_options = {}
      @engine_object = EngineObject.new(kw: 1)
      @app_object = AppObject.new(kw: 2)
    end

    include BlogEngine.routes.mounted_helpers

    # Inside Engine
    test "[ENGINE] generating engine's URL use SCRIPT_NAME from request" do
      get "/pure-awesomeness/blog/posts/1"
      assert_equal "/pure-awesomeness/blog/posts/1", response.body
    end

    test "[ENGINE] generating application's URL never uses SCRIPT_NAME from request" do
      get "/pure-awesomeness/blog/url_to_application"
      assert_equal "/generate", response.body
    end

    test "[ENGINE] generating engine's URL with polymorphic path" do
      get "/pure-awesomeness/blog/polymorphic_path_for_engine"
      assert_equal "/pure-awesomeness/blog/posts/1", response.body
    end

    test "[ENGINE] url_helpers from engine have higher priority than application's url_helpers" do
      get "/awesome/blog/conflicting_url"
      assert_equal "engine", response.body
    end

    test "[ENGINE] relative path root uses SCRIPT_NAME from request" do
      get "/awesome/blog/relative_path_root"
      verify_redirect "http://www.example.com/awesome/blog"
    end

    test "[ENGINE] relative path redirect uses SCRIPT_NAME from request" do
      get "/awesome/blog/relative_path_redirect"
      verify_redirect "http://www.example.com/awesome/blog/foo"
    end

    test "[ENGINE] relative option root uses SCRIPT_NAME from request" do
      get "/awesome/blog/relative_option_root"
      verify_redirect "http://www.example.com/awesome/blog"
    end

    test "[ENGINE] relative option redirect uses SCRIPT_NAME from request" do
      get "/awesome/blog/relative_option_redirect"
      verify_redirect "http://www.example.com/awesome/blog/foo"
    end

    test "[ENGINE] relative custom root uses SCRIPT_NAME from request" do
      get "/awesome/blog/relative_custom_root"
      verify_redirect "http://www.example.com/awesome/blog"
    end

    test "[ENGINE] relative custom redirect uses SCRIPT_NAME from request" do
      get "/awesome/blog/relative_custom_redirect"
      verify_redirect "http://www.example.com/awesome/blog/foo"
    end

    test "[ENGINE] absolute path root doesn't use SCRIPT_NAME from request" do
      get "/awesome/blog/absolute_path_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] absolute path redirect doesn't use SCRIPT_NAME from request" do
      get "/awesome/blog/absolute_path_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    test "[ENGINE] absolute option root doesn't use SCRIPT_NAME from request" do
      get "/awesome/blog/absolute_option_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] absolute option redirect doesn't use SCRIPT_NAME from request" do
      get "/awesome/blog/absolute_option_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    test "[ENGINE] absolute custom root doesn't use SCRIPT_NAME from request" do
      get "/awesome/blog/absolute_custom_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] absolute custom redirect doesn't use SCRIPT_NAME from request" do
      get "/awesome/blog/absolute_custom_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    # Inside Application
    test "[APP] generating engine's route includes prefix" do
      get "/generate"
      assert_equal "/awesome/blog/posts/1", response.body
    end

    test "[APP] generating engine's route includes default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = { script_name: "/something" }
      get "/generate"
      assert_equal "/something/awesome/blog/posts/1", response.body
    end

    test "[APP] generating engine's URL with polymorphic path" do
      get "/polymorphic_path_for_engine"
      assert_equal "/awesome/blog/posts/1", response.body
    end

    test "polymorphic_path_for_app" do
      get "/polymorphic_path_for_app"
      assert_equal "/posts/1", response.body
    end

    test "[APP] generating engine's URL with url_for(@post)" do
      get "/polymorphic_with_url_for"
      assert_equal "http://www.example.com/awesome/blog/posts/1", response.body
    end

    test "[APP] instance variable with same name as engine" do
      get "/ivar_usage"
      assert_equal "/awesome/blog/posts/1", response.body
    end

    # Inside any Object
    test "[OBJECT] proxy route should override respond_to?() as expected" do
      assert_respond_to blog_engine, :named_helper_that_should_be_invoked_only_in_respond_to_test_path
    end

    test "[OBJECT] generating engine's route includes prefix" do
      assert_equal "/awesome/blog/posts/1", engine_object.post_path(id: 1)
    end

    test "[OBJECT] generating engine's route includes dynamic prefix" do
      assert_equal "/pure-awesomeness/blog/posts/3", engine_object.post_path(id: 3, omg: "pure-awesomeness")
    end

    test "[OBJECT] generating engine's route includes default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = { script_name: "/something" }
      assert_equal "/something/pure-awesomeness/blog/posts/3", engine_object.post_path(id: 3, omg: "pure-awesomeness")
    end

    test "[OBJECT] generating application's route" do
      assert_equal "/", app_object.root_path
    end

    test "[OBJECT] generating application's route includes default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = { script_name: "/something" }
      assert_equal "/something/", app_object.root_path
    end

    test "[OBJECT] generating application's route includes default_url_options[:trailing_slash]" do
      RailsApplication.routes.default_url_options[:trailing_slash] = true
      assert_equal "/awesome/blog/posts", engine_object.posts_path
    end

    test "[OBJECT] generating engine's route with url_for" do
      path = engine_object.url_for(controller: "inside_engine_generating",
                                   action: "show",
                                   only_path: true,
                                   omg: "omg",
                                   id: 1)
      assert_equal "/omg/blog/posts/1", path
    end

    test "[OBJECT] generating engine's route with named route helpers" do
      path = engine_object.posts_path
      assert_equal "/awesome/blog/posts", path

      path = engine_object.posts_url(host: "example.com")
      assert_equal "http://example.com/awesome/blog/posts", path
    end

    test "[OBJECT] generating engine's route with polymorphic_url" do
      path = engine_object.polymorphic_path(Post.new)
      assert_equal "/awesome/blog/posts/1", path

      path = engine_object.polymorphic_url(Post.new, host: "www.example.com")
      assert_equal "http://www.example.com/awesome/blog/posts/1", path
    end

    private
      def verify_redirect(url, status = 301)
        assert_equal status, response.status
        assert_equal url, response.headers["Location"]
        assert_equal expected_redirect_body(url), response.body
      end

      def expected_redirect_body(url)
        %(<html><body>You are being <a href="#{url}">redirected</a>.</body></html>)
      end
  end

  class EngineMountedAtRoot < ActionDispatch::IntegrationTest
    class BlogEngine
      def self.routes
        @routes ||= begin
          routes = ActionDispatch::Routing::RouteSet.new
          routes.draw do
            get "/posts/:id", to: "posts#show", as: :post

            get "/relative_path_root",       to: redirect("")
            get "/relative_path_redirect",   to: redirect("foo")
            get "/relative_option_root",     to: redirect(path: "")
            get "/relative_option_redirect", to: redirect(path: "foo")
            get "/relative_custom_root",     to: redirect { |params, request| "" }
            get "/relative_custom_redirect", to: redirect { |params, request| "foo" }

            get "/absolute_path_root",       to: redirect("/")
            get "/absolute_path_redirect",   to: redirect("/foo")
            get "/absolute_option_root",     to: redirect(path: "/")
            get "/absolute_option_redirect", to: redirect(path: "/foo")
            get "/absolute_custom_root",     to: redirect { |params, request| "/" }
            get "/absolute_custom_redirect", to: redirect { |params, request| "/foo" }
          end

          routes
        end
      end

      def self.call(env)
        env["action_dispatch.routes"] = routes
        routes.call(env)
      end
    end

    class RailsApplication < Rails::Engine
      routes.draw do
        mount BlogEngine => "/"
      end
    end

    class ::PostsController < ActionController::Base
      include BlogEngine.routes.url_helpers
      include RailsApplication.routes.mounted_helpers

      def show
        render plain: post_path(id: params[:id])
      end
    end

    def app
      RailsApplication.instance
    end

    test "generating path inside engine" do
      get "/posts/1"
      assert_equal "/posts/1", response.body
    end

    test "[ENGINE] relative path root uses SCRIPT_NAME from request" do
      get "/relative_path_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] relative path redirect uses SCRIPT_NAME from request" do
      get "/relative_path_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    test "[ENGINE] relative option root uses SCRIPT_NAME from request" do
      get "/relative_option_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] relative option redirect uses SCRIPT_NAME from request" do
      get "/relative_option_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    test "[ENGINE] relative custom root uses SCRIPT_NAME from request" do
      get "/relative_custom_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] relative custom redirect uses SCRIPT_NAME from request" do
      get "/relative_custom_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    test "[ENGINE] absolute path root doesn't use SCRIPT_NAME from request" do
      get "/absolute_path_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] absolute path redirect doesn't use SCRIPT_NAME from request" do
      get "/absolute_path_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    test "[ENGINE] absolute option root doesn't use SCRIPT_NAME from request" do
      get "/absolute_option_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] absolute option redirect doesn't use SCRIPT_NAME from request" do
      get "/absolute_option_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    test "[ENGINE] absolute custom root doesn't use SCRIPT_NAME from request" do
      get "/absolute_custom_root"
      verify_redirect "http://www.example.com/"
    end

    test "[ENGINE] absolute custom redirect doesn't use SCRIPT_NAME from request" do
      get "/absolute_custom_redirect"
      verify_redirect "http://www.example.com/foo"
    end

    private
      def verify_redirect(url, status = 301)
        assert_equal status, response.status
        assert_equal url, response.headers["Location"]
        assert_equal expected_redirect_body(url), response.body
      end

      def expected_redirect_body(url)
        %(<html><body>You are being <a href="#{url}">redirected</a>.</body></html>)
      end
  end
end
