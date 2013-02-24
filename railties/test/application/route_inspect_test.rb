require 'test/unit'
require 'mocha/setup'
require 'rails/application/route_inspector'
require 'action_controller'
require 'rails/engine'

module ApplicationTests
  class RouteInspectTest < Test::Unit::TestCase
    def setup
      @set = ActionDispatch::Routing::RouteSet.new
      @inspector = Rails::Application::RouteInspector.new
      app = ActiveSupport::OrderedOptions.new
      app.config = ActiveSupport::OrderedOptions.new
      app.config.assets = ActiveSupport::OrderedOptions.new
      app.config.assets.prefix = '/sprockets'
      Rails.stubs(:application).returns(app)
    end

    def test_displaying_routes_for_engines
      engine = Class.new(Rails::Engine) do
        def self.inspect
          "Blog::Engine"
        end
      end
      engine.routes.draw do
        get '/cart', :to => 'cart#show'
      end

      @set.draw do
        get '/custom/assets', :to => 'custom_assets#show'
        mount engine => "/blog", :as => "blog"
      end

      output = @inspector.format @set.routes
      expected = [
        "custom_assets GET /custom/assets(.:format) custom_assets#show",
        "         blog     /blog                    Blog::Engine",
        "\nRoutes for Blog::Engine:",
        "cart GET /cart(.:format) cart#show"
      ]
      assert_equal expected, output
    end

    def test_cart_inspect
      @set.draw do
        get '/cart', :to => 'cart#show'
      end
      output = @inspector.format @set.routes
      assert_equal ["cart GET /cart(.:format) cart#show"], output
    end

    def test_inspect_shows_custom_assets
      @set.draw do
        get '/custom/assets', :to => 'custom_assets#show'
      end
      output = @inspector.format @set.routes
      assert_equal ["custom_assets GET /custom/assets(.:format) custom_assets#show"], output
    end

    def test_inspect_routes_shows_resources_route
      @set.draw do
        resources :articles
      end
      output = @inspector.format @set.routes
      expected = [
        "    articles GET    /articles(.:format)          articles#index",
        "             POST   /articles(.:format)          articles#create",
        " new_article GET    /articles/new(.:format)      articles#new",
        "edit_article GET    /articles/:id/edit(.:format) articles#edit",
        "     article GET    /articles/:id(.:format)      articles#show",
        "             PUT    /articles/:id(.:format)      articles#update",
        "             DELETE /articles/:id(.:format)      articles#destroy" ]
      assert_equal expected, output
    end

    def test_inspect_routes_shows_root_route
      @set.draw do
        root :to => 'pages#main'
      end
      output = @inspector.format @set.routes
      assert_equal ["root  / pages#main"], output
    end

    def test_inspect_routes_shows_dynamic_action_route
      @set.draw do
        match 'api/:action' => 'api'
      end
      output = @inspector.format @set.routes
      assert_equal ["  /api/:action(.:format) api#:action"], output
    end

    def test_inspect_routes_shows_controller_and_action_only_route
      @set.draw do
        match ':controller/:action'
      end
      output = @inspector.format @set.routes
      assert_equal ["  /:controller/:action(.:format) :controller#:action"], output
    end

    def test_inspect_routes_shows_controller_and_action_route_with_constraints
      @set.draw do
        match ':controller(/:action(/:id))', :id => /\d+/
      end
      output = @inspector.format @set.routes
      assert_equal ["  /:controller(/:action(/:id))(.:format) :controller#:action {:id=>/\\d+/}"], output
    end

    def test_rake_routes_shows_route_with_defaults
      @set.draw do
        match 'photos/:id' => 'photos#show', :defaults => {:format => 'jpg'}
      end
      output = @inspector.format @set.routes
      assert_equal [%Q[  /photos/:id(.:format) photos#show {:format=>"jpg"}]], output
    end

    def test_rake_routes_shows_route_with_constraints
      @set.draw do
        match 'photos/:id' => 'photos#show', :id => /[A-Z]\d{5}/
      end
      output = @inspector.format @set.routes
      assert_equal ["  /photos/:id(.:format) photos#show {:id=>/[A-Z]\\d{5}/}"], output
    end

    class RackApp
      def self.call(env)
      end
    end

    def test_rake_routes_shows_route_with_rack_app
      @set.draw do
        match 'foo/:id' => RackApp, :id => /[A-Z]\d{5}/
      end
      output = @inspector.format @set.routes
      assert_equal ["  /foo/:id(.:format) #{RackApp.name} {:id=>/[A-Z]\\d{5}/}"], output
    end

    def test_rake_routes_shows_route_with_rack_app_nested_with_dynamic_constraints
      constraint = Class.new do
        def inspect
          "( my custom constraint )"
        end
      end

      @set.draw do
        scope :constraint => constraint.new do
          mount RackApp => '/foo'
        end
      end

      output = @inspector.format @set.routes
      assert_equal ["  /foo #{RackApp.name} {:constraint=>( my custom constraint )}"], output
    end

    def test_rake_routes_dont_show_app_mounted_in_assets_prefix
      @set.draw do
        match '/sprockets' => RackApp
      end
      output = @inspector.format @set.routes
      assert_no_match(/RackApp/, output.first)
      assert_no_match(/\/sprockets/, output.first)
    end
  end
end
