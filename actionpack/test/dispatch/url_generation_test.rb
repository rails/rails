require 'abstract_unit'

module TestUrlGeneration
  class WithMountPoint < ActionDispatch::IntegrationTest
    Routes = ActionDispatch::Routing::RouteSet.new
    Routes.draw { match "/foo", :to => "my_route_generating#index", :as => :foo }

    class ::MyRouteGeneratingController < ActionController::Base
      include Routes.url_helpers
      def index
        render :text => foo_path
      end
    end

    include Routes.url_helpers

    def _routes
      Routes
    end

    def app
      Routes
    end

    test "generating URLS normally" do
      assert_equal "/foo", foo_path
    end

    test "accepting a :script_name option" do
      assert_equal "/bar/foo", foo_path(:script_name => "/bar")
    end

    test "the request's SCRIPT_NAME takes precedence over the routes'" do
      get "/foo", {}, 'SCRIPT_NAME' => "/new", 'action_dispatch.routes' => Routes
      assert_equal "/new/foo", response.body
    end

    test "handling http protocol with https set" do
      https!
      assert_equal "http://www.example.com/foo", foo_url(:protocol => "http")
    end
  end
end

