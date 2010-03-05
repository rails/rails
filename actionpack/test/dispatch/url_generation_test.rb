require 'abstract_unit'

module TestUrlGeneration
  class WithoutMountpoint < ActiveSupport::TestCase
    setup do
      app = lambda { |env| [200, {}, "Hello"] }
      @router = ActionDispatch::Routing::RouteSet.new
      @router.draw do
        match "/foo", :to => app, :as => :foo
      end

      singleton_class.send(:include, @router.url_helpers)
    end

    test "generating URLS normally" do
      assert_equal "/foo", foo_path
    end

    test "accepting a :script_name option" do
      assert_equal "/bar/foo", foo_path(:script_name => "/bar")
    end
  end

  class WithMountPoint < ActionDispatch::IntegrationTest
    Router = ActionDispatch::Routing::RouteSet.new(:mount_point => "/baz")
    Router.draw { match "/foo", :to => "my_route_generating#index", :as => :foo }

    class ::MyRouteGeneratingController < ActionController::Base
      include Router.url_helpers
      def index
        render :text => foo_path
      end
    end

    include Router.url_helpers

    def _router
      Router
    end

    def app
      Router
    end

    test "using the default :script_name option" do
      assert_equal "/baz/foo", foo_path
    end

    test "overriding the default :script_name option" do
      assert_equal "/bar/foo", foo_path(:script_name => "/bar")
    end

    test "the request's SCRIPT_NAME takes precedence over the router's" do
      get "/foo", {}, 'SCRIPT_NAME' => "/new"
      assert_equal "/new/foo", response.body
    end
  end
end