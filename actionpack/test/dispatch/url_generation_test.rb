require "abstract_unit"

module TestUrlGeneration
  class WithMountPoint < ActionDispatch::IntegrationTest
    Routes = ActionDispatch::Routing::RouteSet.new
    include Routes.url_helpers

    class ::MyRouteGeneratingController < ActionController::Base
      include Routes.url_helpers
      def index
        render plain: foo_path
      end
    end

    Routes.draw do
      get "/foo", :to => "my_route_generating#index", :as => :foo

      resources :bars

      mount MyRouteGeneratingController.action(:index), at: "/bar"
    end

    APP = build_app Routes

    def _routes
      Routes
    end

    def app
      APP
    end

    test "generating URLS normally" do
      assert_equal "/foo", foo_path
    end

    test "accepting a :script_name option" do
      assert_equal "/bar/foo", foo_path(:script_name => "/bar")
    end

    test "the request's SCRIPT_NAME takes precedence over the route" do
      get "/foo", headers: { "SCRIPT_NAME" => "/new", "action_dispatch.routes" => Routes }
      assert_equal "/new/foo", response.body
    end

    test "the request's SCRIPT_NAME wraps the mounted app's" do
      get "/new/bar/foo", headers: { "SCRIPT_NAME" => "/new", "PATH_INFO" => "/bar/foo", "action_dispatch.routes" => Routes }
      assert_equal "/new/bar/foo", response.body
    end

    test "handling http protocol with https set" do
      https!
      assert_equal "http://www.example.com/foo", foo_url(:protocol => "http")
    end

    test "extracting protocol from host when protocol not present" do
      assert_equal "httpz://www.example.com/foo", foo_url(host: "httpz://www.example.com", protocol: nil)
    end

    test "formatting host when protocol is present" do
      assert_equal "http://www.example.com/foo", foo_url(host: "httpz://www.example.com", protocol: "http://")
    end

    test "default ports are removed from the host" do
      assert_equal "http://www.example.com/foo", foo_url(host: "www.example.com:80", protocol: "http://")
      assert_equal "https://www.example.com/foo", foo_url(host: "www.example.com:443", protocol: "https://")
    end

    test "port is extracted from the host" do
      assert_equal "http://www.example.com:8080/foo", foo_url(host: "www.example.com:8080", protocol: "http://")
      assert_equal "//www.example.com:8080/foo", foo_url(host: "www.example.com:8080", protocol: "//")
      assert_equal "//www.example.com:80/foo", foo_url(host: "www.example.com:80", protocol: "//")
    end

    test "port option is used" do
      assert_equal "http://www.example.com:8080/foo", foo_url(host: "www.example.com", protocol: "http://", port: 8080)
      assert_equal "//www.example.com:8080/foo", foo_url(host: "www.example.com", protocol: "//", port: 8080)
      assert_equal "//www.example.com:80/foo", foo_url(host: "www.example.com", protocol: "//", port: 80)
    end

    test "port option overrides the host" do
      assert_equal "http://www.example.com:8080/foo", foo_url(host: "www.example.com:8443", protocol: "http://", port: 8080)
      assert_equal "//www.example.com:8080/foo", foo_url(host: "www.example.com:8443", protocol: "//", port: 8080)
      assert_equal "//www.example.com:80/foo", foo_url(host: "www.example.com:443", protocol: "//", port: 80)
    end

    test "port option disables the host when set to nil" do
      assert_equal "http://www.example.com/foo", foo_url(host: "www.example.com:8443", protocol: "http://", port: nil)
      assert_equal "//www.example.com/foo", foo_url(host: "www.example.com:8443", protocol: "//", port: nil)
    end

    test "port option disables the host when set to false" do
      assert_equal "http://www.example.com/foo", foo_url(host: "www.example.com:8443", protocol: "http://", port: false)
      assert_equal "//www.example.com/foo", foo_url(host: "www.example.com:8443", protocol: "//", port: false)
    end

    test "keep subdomain when key is true" do
      assert_equal "http://www.example.com/foo", foo_url(subdomain: true)
    end

    test "keep subdomain when key is missing" do
      assert_equal "http://www.example.com/foo", foo_url
    end

    test "omit subdomain when key is nil" do
      assert_equal "http://example.com/foo", foo_url(subdomain: nil)
    end

    test "omit subdomain when key is false" do
      assert_equal "http://example.com/foo", foo_url(subdomain: false)
    end

    test "omit subdomain when key is blank" do
      assert_equal "http://example.com/foo", foo_url(subdomain: "")
    end

    test "generating URLs with trailing slashes" do
      assert_equal "/bars.json", bars_path(
        trailing_slash: true,
        format: "json"
      )
    end

    test "generating URLS with querystring and trailing slashes" do
      assert_equal "/bars.json?a=b", bars_path(
        trailing_slash: true,
        a: "b",
        format: "json"
      )
    end

    test "generating URLS with empty querystring" do
      assert_equal "/bars.json", bars_path(
        a: {},
        format: "json"
      )
    end

  end
end

