require 'abstract_unit'
require 'rails/engine'
require 'action_dispatch/routing/inspector'

module ActionDispatch
  module Routing
    class RoutesInspectorTest < ActiveSupport::TestCase
      def setup
        @set = ActionDispatch::Routing::RouteSet.new
        app = ActiveSupport::OrderedOptions.new
        app.config = ActiveSupport::OrderedOptions.new
        app.config.assets = ActiveSupport::OrderedOptions.new
        app.config.assets.prefix = '/sprockets'
        Rails.stubs(:application).returns(app)
        Rails.stubs(:env).returns("development")
      end

      def draw(options = {}, &block)
        @set.draw(&block)
        inspector = ActionDispatch::Routing::RoutesInspector.new(@set.routes)
        inspector.format(ActionDispatch::Routing::ConsoleFormatter.new, options[:filter]).split("\n")
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

        output = draw do
          get '/custom/assets', :to => 'custom_assets#show'
          mount engine => "/blog", :as => "blog"
        end

        expected = [
          "custom_assets GET /custom/assets(.:format) custom_assets#show",
          "         blog     /blog                    Blog::Engine",
          "",
          "Routes for Blog::Engine:",
          "cart GET /cart(.:format) cart#show"
        ]
        assert_equal expected, output
      end

      def test_cart_inspect
        output = draw do
          get '/cart', :to => 'cart#show'
        end
        assert_equal ["cart GET /cart(.:format) cart#show"], output
      end

      def test_inspect_shows_custom_assets
        output = draw do
          get '/custom/assets', :to => 'custom_assets#show'
        end
        assert_equal ["custom_assets GET /custom/assets(.:format) custom_assets#show"], output
      end

      def test_inspect_routes_shows_resources_route
        output = draw do
          resources :articles
        end
        expected = [
          "    articles GET    /articles(.:format)          articles#index",
          "             POST   /articles(.:format)          articles#create",
          " new_article GET    /articles/new(.:format)      articles#new",
          "edit_article GET    /articles/:id/edit(.:format) articles#edit",
          "     article GET    /articles/:id(.:format)      articles#show",
          "             PATCH  /articles/:id(.:format)      articles#update",
          "             PUT    /articles/:id(.:format)      articles#update",
          "             DELETE /articles/:id(.:format)      articles#destroy" ]
        assert_equal expected, output
      end

      def test_inspect_routes_shows_root_route
        output = draw do
          root :to => 'pages#main'
        end
        assert_equal ["root GET / pages#main"], output
      end

      def test_inspect_routes_shows_dynamic_action_route
        output = draw do
          get 'api/:action' => 'api'
        end
        assert_equal [" GET /api/:action(.:format) api#:action"], output
      end

      def test_inspect_routes_shows_controller_and_action_only_route
        output = draw do
          get ':controller/:action'
        end
        assert_equal [" GET /:controller/:action(.:format) :controller#:action"], output
      end

      def test_inspect_routes_shows_controller_and_action_route_with_constraints
        output = draw do
          get ':controller(/:action(/:id))', :id => /\d+/
        end
        assert_equal [" GET /:controller(/:action(/:id))(.:format) :controller#:action {:id=>/\\d+/}"], output
      end

      def test_rake_routes_shows_route_with_defaults
        output = draw do
          get 'photos/:id' => 'photos#show', :defaults => {:format => 'jpg'}
        end
        assert_equal [%Q[ GET /photos/:id(.:format) photos#show {:format=>"jpg"}]], output
      end

      def test_rake_routes_shows_route_with_constraints
        output = draw do
          get 'photos/:id' => 'photos#show', :id => /[A-Z]\d{5}/
        end
        assert_equal [" GET /photos/:id(.:format) photos#show {:id=>/[A-Z]\\d{5}/}"], output
      end

      class RackApp
        def self.call(env)
        end
      end

      def test_rake_routes_shows_route_with_rack_app
        output = draw do
          get 'foo/:id' => RackApp, :id => /[A-Z]\d{5}/
        end
        assert_equal [" GET /foo/:id(.:format) #{RackApp.name} {:id=>/[A-Z]\\d{5}/}"], output
      end

      def test_rake_routes_shows_route_with_rack_app_nested_with_dynamic_constraints
        constraint = Class.new do
          def inspect
            "( my custom constraint )"
          end
        end

        output = draw do
          scope :constraint => constraint.new do
            mount RackApp => '/foo'
          end
        end

        assert_equal ["  /foo #{RackApp.name} {:constraint=>( my custom constraint )}"], output
      end

      def test_rake_routes_dont_show_app_mounted_in_assets_prefix
        output = draw do
          get '/sprockets' => RackApp
        end
        assert_no_match(/RackApp/, output.first)
        assert_no_match(/\/sprockets/, output.first)
      end

      def test_redirect
        output = draw do
          get "/foo"    => redirect("/foo/bar"), :constraints => { :subdomain => "admin" }
          get "/bar"    => redirect(path: "/foo/bar", status: 307)
          get "/foobar" => redirect{ "/foo/bar" }
        end

        assert_equal "   foo GET /foo(.:format)    redirect(301, /foo/bar) {:subdomain=>\"admin\"}", output[0]
        assert_equal "   bar GET /bar(.:format)    redirect(307, path: /foo/bar)", output[1]
        assert_equal "foobar GET /foobar(.:format) redirect(301)", output[2]
      end

      def test_routes_can_be_filtered
        output = draw(filter: 'posts') do
          resources :articles
          resources :posts
        end

        assert_equal ["    posts GET    /posts(.:format)          posts#index",
                      "          POST   /posts(.:format)          posts#create",
                      " new_post GET    /posts/new(.:format)      posts#new",
                      "edit_post GET    /posts/:id/edit(.:format) posts#edit",
                      "     post GET    /posts/:id(.:format)      posts#show",
                      "          PATCH  /posts/:id(.:format)      posts#update",
                      "          PUT    /posts/:id(.:format)      posts#update",
                      "          DELETE /posts/:id(.:format)      posts#destroy"], output
      end
    end
  end
end
