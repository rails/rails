require 'abstract_unit'
require 'rack/test'

module TestGenerationPrefix
  class Post
    extend ActiveModel::Naming

    def to_param
      "1"
    end

    def self.model_name
      klass = "Post"
      def klass.name; self end

      ActiveModel::Name.new(klass)
    end
  end

  class WithMountedEngine < ActionDispatch::IntegrationTest
    include Rack::Test::Methods

    class BlogEngine
      def self.routes
        @routes ||= begin
          routes = ActionDispatch::Routing::RouteSet.new
          routes.draw do
            get "/posts/:id", :to => "inside_engine_generating#show", :as => :post
            get "/posts", :to => "inside_engine_generating#index", :as => :posts
            get "/url_to_application", :to => "inside_engine_generating#url_to_application"
            get "/polymorphic_path_for_engine", :to => "inside_engine_generating#polymorphic_path_for_engine"
            get "/conflicting_url", :to => "inside_engine_generating#conflicting"
            get "/foo", :to => "never#invoked", :as => :named_helper_that_should_be_invoked_only_in_respond_to_test
          end

          routes
        end
      end

      def self.call(env)
        env['action_dispatch.routes'] = routes
        routes.call(env)
      end
    end

    class RailsApplication
      def self.routes
        @routes ||= begin
          routes = ActionDispatch::Routing::RouteSet.new
          routes.draw do
            scope "/:omg", :omg => "awesome" do
              mount BlogEngine => "/blog", :as => "blog_engine"
            end
            get "/posts/:id", :to => "outside_engine_generating#post", :as => :post
            get "/generate", :to => "outside_engine_generating#index"
            get "/polymorphic_path_for_app", :to => "outside_engine_generating#polymorphic_path_for_app"
            get "/polymorphic_path_for_engine", :to => "outside_engine_generating#polymorphic_path_for_engine"
            get "/polymorphic_with_url_for", :to => "outside_engine_generating#polymorphic_with_url_for"
            get "/conflicting_url", :to => "outside_engine_generating#conflicting"
            get "/ivar_usage", :to => "outside_engine_generating#ivar_usage"
            root :to => "outside_engine_generating#index"
          end

          routes
        end
      end

      def self.call(env)
        env['action_dispatch.routes'] = routes
        routes.call(env)
      end
    end

    # force draw
    RailsApplication.routes
    RailsApplication.routes.define_mounted_helper(:main_app)

    class ::InsideEngineGeneratingController < ActionController::Base
      include BlogEngine.routes.url_helpers
      include RailsApplication.routes.mounted_helpers

      def index
        render :text => posts_path
      end

      def show
        render :text => post_path(:id => params[:id])
      end

      def url_to_application
        path = main_app.url_for(:controller => "outside_engine_generating",
                                :action => "index",
                                :only_path => true)
        render :text => path
      end

      def polymorphic_path_for_engine
        render :text => polymorphic_path(Post.new)
      end

      def conflicting
        render :text => "engine"
      end
    end

    class ::OutsideEngineGeneratingController < ActionController::Base
      include BlogEngine.routes.mounted_helpers
      include RailsApplication.routes.url_helpers

      def index
        render :text => blog_engine.post_path(:id => 1)
      end

      def polymorphic_path_for_engine
        render :text => blog_engine.polymorphic_path(Post.new)
      end

      def polymorphic_path_for_app
        render :text => polymorphic_path(Post.new)
      end

      def polymorphic_with_url_for
        render :text => blog_engine.url_for(Post.new)
      end

      def conflicting
        render :text => "application"
      end

      def ivar_usage
        @blog_engine = "Not the engine route helper"
        render :text => blog_engine.post_path(:id => 1)
      end
    end

    class EngineObject
      include ActionDispatch::Routing::UrlFor
      include BlogEngine.routes.url_helpers
    end

    class AppObject
      include ActionDispatch::Routing::UrlFor
      include RailsApplication.routes.url_helpers
    end

    def app
      RailsApplication
    end

    def engine_object
      @engine_object ||= EngineObject.new
    end

    def app_object
      @app_object ||= AppObject.new
    end

    def setup
      RailsApplication.routes.default_url_options = {}
    end

    include BlogEngine.routes.mounted_helpers

    # Inside Engine
    test "[ENGINE] generating engine's url use SCRIPT_NAME from request" do
      get "/pure-awesomeness/blog/posts/1"
      assert_equal "/pure-awesomeness/blog/posts/1", last_response.body
    end

    test "[ENGINE] generating application's url never uses SCRIPT_NAME from request" do
      get "/pure-awesomeness/blog/url_to_application"
      assert_equal "/generate", last_response.body
    end

    test "[ENGINE] generating engine's url with polymorphic path" do
      get "/pure-awesomeness/blog/polymorphic_path_for_engine"
      assert_equal "/pure-awesomeness/blog/posts/1", last_response.body
    end

    test "[ENGINE] url_helpers from engine have higher priotity than application's url_helpers" do
      get "/awesome/blog/conflicting_url"
      assert_equal "engine", last_response.body
    end

    # Inside Application
    test "[APP] generating engine's route includes prefix" do
      get "/generate"
      assert_equal "/awesome/blog/posts/1", last_response.body
    end

    test "[APP] generating engine's route includes default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = {:script_name => "/something"}
      get "/generate"
      assert_equal "/something/awesome/blog/posts/1", last_response.body
    end

    test "[APP] generating engine's url with polymorphic path" do
      get "/polymorphic_path_for_engine"
      assert_equal "/awesome/blog/posts/1", last_response.body
    end

    test "polymorphic_path_for_app" do
      get "/polymorphic_path_for_app"
      assert_equal "/posts/1", last_response.body
    end

    test "[APP] generating engine's url with url_for(@post)" do
      get "/polymorphic_with_url_for"
      assert_equal "http://example.org/awesome/blog/posts/1", last_response.body
    end

    test "[APP] instance variable with same name as engine" do
      get "/ivar_usage"
      assert_equal "/awesome/blog/posts/1", last_response.body
    end

    # Inside any Object
    test "[OBJECT] proxy route should override respond_to?() as expected" do
      assert_respond_to blog_engine, :named_helper_that_should_be_invoked_only_in_respond_to_test_path
    end

    test "[OBJECT] generating engine's route includes prefix" do
      assert_equal "/awesome/blog/posts/1", engine_object.post_path(:id => 1)
    end

    test "[OBJECT] generating engine's route includes dynamic prefix" do
      assert_equal "/pure-awesomeness/blog/posts/3", engine_object.post_path(:id => 3, :omg => "pure-awesomeness")
    end

    test "[OBJECT] generating engine's route includes default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = {:script_name => "/something"}
      assert_equal "/something/pure-awesomeness/blog/posts/3", engine_object.post_path(:id => 3, :omg => "pure-awesomeness")
    end

    test "[OBJECT] generating application's route" do
      assert_equal "/", app_object.root_path
    end

    test "[OBJECT] generating application's route includes default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = {:script_name => "/something"}
      assert_equal "/something/", app_object.root_path
    end

    test "[OBJECT] generating engine's route with url_for" do
      path = engine_object.url_for(:controller => "inside_engine_generating",
                                   :action => "show",
                                   :only_path => true,
                                   :omg => "omg",
                                   :id => 1)
      assert_equal "/omg/blog/posts/1", path
    end

    test "[OBJECT] generating engine's route with named helpers" do
      path = engine_object.posts_path
      assert_equal "/awesome/blog/posts", path

      path = engine_object.posts_url(:host => "example.com")
      assert_equal "http://example.com/awesome/blog/posts", path
    end

    test "[OBJECT] generating engine's route with polymorphic_url" do
      path = engine_object.polymorphic_path(Post.new)
      assert_equal "/awesome/blog/posts/1", path

      path = engine_object.polymorphic_url(Post.new, :host => "www.example.com")
      assert_equal "http://www.example.com/awesome/blog/posts/1", path
    end
  end

  class EngineMountedAtRoot < ActionDispatch::IntegrationTest
    include Rack::Test::Methods

    class BlogEngine
      def self.routes
        @routes ||= begin
          routes = ActionDispatch::Routing::RouteSet.new
          routes.draw do
            get "/posts/:id", :to => "posts#show", :as => :post
          end

          routes
        end
      end

      def self.call(env)
        env['action_dispatch.routes'] = routes
        routes.call(env)
      end
    end

    class RailsApplication
      def self.routes
        @routes ||= begin
          routes = ActionDispatch::Routing::RouteSet.new
          routes.draw do
            mount BlogEngine => "/"
          end

          routes
        end
      end

      def self.call(env)
        env['action_dispatch.routes'] = routes
        routes.call(env)
      end
    end

    # force draw
    RailsApplication.routes

    class ::PostsController < ActionController::Base
      include BlogEngine.routes.url_helpers
      include RailsApplication.routes.mounted_helpers

      def show
        render :text => post_path(:id => params[:id])
      end
    end

    def app
      RailsApplication
    end

    test "generating path inside engine" do
      get "/posts/1"
      assert_equal "/posts/1", last_response.body
    end
  end
end
