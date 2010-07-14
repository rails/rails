require 'abstract_unit'

module TestGenerationPrefix
  class WithMountedEngine < ActionDispatch::IntegrationTest
    require 'rack/test'
    include Rack::Test::Methods

    class BlogEngine
      def self.routes
        @routes ||= begin
          routes = ActionDispatch::Routing::RouteSet.new
          routes.draw do
            match "/posts/:id", :to => "inside_engine_generating#show", :as => :post
            match "/posts", :to => "inside_engine_generating#index", :as => :posts
            match "/url_to_application", :to => "inside_engine_generating#url_to_application"
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
              mount BlogEngine => "/blog"
            end
            match "/generate", :to => "outside_engine_generating#index"
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

    class ::InsideEngineGeneratingController < ActionController::Base
      include BlogEngine.routes.url_helpers

      def index
        render :text => posts_path
      end

      def show
        render :text => post_path(:id => params[:id])
      end

      def url_to_application
        path = url_for( RailsApplication,
                        :controller => "outside_engine_generating",
                        :action => "index",
                        :only_path => true)
        render :text => path
      end
    end

    class ::OutsideEngineGeneratingController < ActionController::Base
      def index
        render :text => url_for(BlogEngine, :post_path, :id => 1)
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

    # force draw
    RailsApplication.routes

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

    # Inside Engine
    test "[ENGINE] generating engine's url use SCRIPT_NAME from request" do
      get "/pure-awesomeness/blog/posts/1"
      assert_equal "/pure-awesomeness/blog/posts/1", last_response.body
    end

    test "[ENGINE] generating application's url never uses SCRIPT_NAME from request" do
      get "/pure-awesomeness/blog/url_to_application"
      assert_equal "/generate", last_response.body
    end

    test "[ENGINE] generating application's url includes default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = {:script_name => "/something"}
      get "/pure-awesomeness/blog/url_to_application"
      assert_equal "/something/generate", last_response.body
    end

    test "[ENGINE] generating application's url should give higher priority to default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = {:script_name => "/something"}
      get "/pure-awesomeness/blog/url_to_application", {}, 'SCRIPT_NAME' => '/foo'
      assert_equal "/something/generate", last_response.body
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

    test "[APP] generating engine's route should give higher priority to default_url_options[:script_name]" do
      RailsApplication.routes.default_url_options = {:script_name => "/something"}
      get "/generate", {}, 'SCRIPT_NAME' => "/foo"
      assert_equal "/something/awesome/blog/posts/1", last_response.body
    end

    # Inside any Object
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
      path = engine_object.url_for(BlogEngine,
                                   :controller => "inside_engine_generating",
                                   :action => "show",
                                   :only_path => true,
                                   :omg => "omg",
                                   :id => 1)
      assert_equal "/omg/blog/posts/1", path

      path = engine_object.url_for(BlogEngine, :posts_path)
      assert_equal "/awesome/blog/posts", path

      path = engine_object.url_for(BlogEngine, :posts_url, :host => "example.com")
      assert_equal "http://example.com/awesome/blog/posts", path
    end
  end
end
