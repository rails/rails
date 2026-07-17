# frozen_string_literal: true

require "abstract_unit"
require "rails/engine"
require "action_dispatch/routing/inspector"
require "io/console/size"

class MountedRackApp
  def self.call(env)
  end
end

class Rails::DummyController
end

module InspectorTestApp
  class PostsController < ActionController::Base
    def index
    end

    def show
    end
  end

  module Admin
    class UsersController < ActionController::Base
      def index
      end
    end
  end
end

module ActionDispatch
  module Routing
    class RoutesInspectorTest < ActiveSupport::TestCase
      class RouteCollector < ConsoleFormatter::Base
        def initialize
          super
          @routes = []
        end

        def section(routes)
          @routes.concat(routes)
        end

        def result
          @routes
        end
      end

      setup do
        @set = ActionDispatch::Routing::RouteSet.new
      end

      def test_displaying_routes_for_engines
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        engine.routes.draw do
          get "/cart", to: "cart#show"
        end

        output = draw do
          get "/custom/assets", to: "custom_assets#show"
          mount engine => "/blog", :as => "blog"
        end

        assert_equal [
          "Routes for application:",
          "       Prefix Verb URI Pattern              Controller#Action",
          "custom_assets GET  /custom/assets(.:format) custom_assets#show",
          "         blog      /blog                    Blog::Engine",
          "",
          "Routes for Blog::Engine:",
          "Prefix Verb URI Pattern     Controller#Action",
          "  cart GET  /cart(.:format) cart#show"
        ], output
      end

      def test_displaying_routes_for_engines_without_routes
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        engine.routes.draw do
        end

        output = draw do
          mount engine => "/blog", as: "blog"
        end

        assert_equal [
          "Routes for application:",
          "Prefix Verb URI Pattern Controller#Action",
          "  blog      /blog       Blog::Engine",
          "",
          "Routes for Blog::Engine:",
          "No routes defined.",
        ], output
      end

      def test_cart_inspect
        output = draw do
          get "/cart", to: "cart#show"
        end

        assert_equal [
          "Prefix Verb URI Pattern     Controller#Action",
          "  cart GET  /cart(.:format) cart#show"
        ], output
      end

      def test_articles_inspect_with_multiple_verbs
        output = draw do
          match "articles/:id", to: "articles#update", via: [:put, :patch]
        end

        assert_equal [
          "Prefix Verb      URI Pattern             Controller#Action",
          "       PUT|PATCH /articles/:id(.:format) articles#update"
        ], output
      end

      def test_inspect_shows_custom_assets
        output = draw do
          get "/custom/assets", to: "custom_assets#show"
        end

        assert_equal [
          "       Prefix Verb URI Pattern              Controller#Action",
          "custom_assets GET  /custom/assets(.:format) custom_assets#show"
        ], output
      end

      def test_inspect_routes_shows_resources_route
        output = draw do
          resources :articles
        end

        assert_equal [
          "      Prefix Verb   URI Pattern                  Controller#Action",
          "    articles GET    /articles(.:format)          articles#index",
          "             POST   /articles(.:format)          articles#create",
          " new_article GET    /articles/new(.:format)      articles#new",
          "edit_article GET    /articles/:id/edit(.:format) articles#edit",
          "     article GET    /articles/:id(.:format)      articles#show",
          "             PATCH  /articles/:id(.:format)      articles#update",
          "             PUT    /articles/:id(.:format)      articles#update",
          "             DELETE /articles/:id(.:format)      articles#destroy"
        ], output
      end

      def test_inspect_routes_shows_root_route
        output = draw do
          root to: "pages#main"
        end

        assert_equal [
          "Prefix Verb URI Pattern Controller#Action",
          "  root GET  /           pages#main"
        ], output
      end

      def test_inspect_routes_shows_dynamic_action_route
        output = draw do
          ActionDispatch.deprecator.silence do
            get "api/:action" => "api"
          end
        end

        assert_equal [
          "Prefix Verb URI Pattern            Controller#Action",
          "       GET  /api/:action(.:format) api#:action"
        ], output
      end

      def test_inspect_routes_shows_controller_and_action_only_route
        output = draw do
          ActionDispatch.deprecator.silence do
            get ":controller/:action"
          end
        end

        assert_equal [
          "Prefix Verb URI Pattern                    Controller#Action",
          "       GET  /:controller/:action(.:format) :controller#:action"
        ], output
      end

      def test_inspect_routes_shows_controller_and_action_route_with_constraints
        output = draw do
          ActionDispatch.deprecator.silence do
            get ":controller(/:action(/:id))", id: /\d+/
          end
        end

        assert_equal [
          "Prefix Verb URI Pattern                            Controller#Action",
          "       GET  /:controller(/:action(/:id))(.:format) :controller#:action #{{ id: /\d+/ }}"
        ], output
      end

      def test_rails_routes_shows_route_with_defaults
        output = draw do
          get "photos/:id" => "photos#show", :defaults => { format: "jpg" }
        end

        assert_equal [
          "Prefix Verb URI Pattern           Controller#Action",
          "       GET  /photos/:id(.:format) photos#show #{{ format: "jpg" }}"
        ], output
      end

      def test_rails_routes_shows_route_with_constraints
        output = draw do
          get "photos/:id" => "photos#show", :id => /[A-Z]\d{5}/
        end

        assert_equal [
          "Prefix Verb URI Pattern           Controller#Action",
          "       GET  /photos/:id(.:format) photos#show #{{ id: /[A-Z]\d{5}/ }}"
        ], output
      end

      def test_rails_routes_shows_routes_with_dashes
        output = draw do
          get "about-us" => "pages#about_us"
          get "our-work/latest"

          resources :photos, only: [:show] do
            get "user-favorites", on: :collection
            get "preview-photo", on: :member
            get "summary-text"
          end
        end

        assert_equal [
          "               Prefix Verb URI Pattern                              Controller#Action",
          "             about_us GET  /about-us(.:format)                      pages#about_us",
          "      our_work_latest GET  /our-work/latest(.:format)               our_work#latest",
          "user_favorites_photos GET  /photos/user-favorites(.:format)         photos#user_favorites",
          "  preview_photo_photo GET  /photos/:id/preview-photo(.:format)      photos#preview_photo",
          "   photo_summary_text GET  /photos/:photo_id/summary-text(.:format) photos#summary_text",
          "                photo GET  /photos/:id(.:format)                    photos#show"
        ], output
      end

      def test_rails_routes_shows_route_with_rack_app
        output = draw do
          get "foo/:id" => MountedRackApp, :id => /[A-Z]\d{5}/
        end

        assert_equal [
          "Prefix Verb URI Pattern        Controller#Action",
          "       GET  /foo/:id(.:format) MountedRackApp #{{ id: /[A-Z]\d{5}/ }}"
        ], output
      end

      def test_rails_routes_shows_named_route_with_mounted_rack_app
        output = draw do
          mount MountedRackApp => "/foo"
        end

        assert_equal [
          "          Prefix Verb URI Pattern Controller#Action",
          "mounted_rack_app      /foo        MountedRackApp"
        ], output
      end

      def test_rails_routes_shows_overridden_named_route_with_mounted_rack_app_with_name
        output = draw do
          mount MountedRackApp => "/foo", as: "blog"
        end

        assert_equal [
          "Prefix Verb URI Pattern Controller#Action",
          "  blog      /foo        MountedRackApp"
        ], output
      end

      def test_rails_routes_shows_route_with_rack_app_nested_with_dynamic_constraints
        constraint = Class.new do
          def inspect
            "( my custom constraint )"
          end
        end

        output = draw do
          scope constraint: constraint.new do
            mount MountedRackApp => "/foo"
          end
        end

        assert_equal [
          "          Prefix Verb URI Pattern Controller#Action",
          "mounted_rack_app      /foo        MountedRackApp #{{ constraint: constraint.new }}"
        ], output
      end

      def test_rails_routes_dont_show_app_mounted_in_assets_prefix
        output = draw do
          get "/sprockets" => MountedRackApp
        end
        assert_no_match(/MountedRackApp/, output.first)
        assert_no_match(/\/sprockets/, output.first)
      end

      def test_rails_routes_shows_route_defined_in_under_assets_prefix
        output = draw do
          scope "/sprockets" do
            get "/foo" => "foo#bar"
          end
        end
        assert_equal [
          "Prefix Verb URI Pattern              Controller#Action",
          "   foo GET  /sprockets/foo(.:format) foo#bar"
        ], output
      end

      def test_redirect
        output = draw do
          get "/foo"    => redirect("/foo/bar"), :constraints => { subdomain: "admin" }
          get "/bar"    => redirect(path: "/foo/bar", status: 307)
          get "/foobar" => redirect { "/foo/bar" }
        end

        assert_equal [
          "Prefix Verb URI Pattern       Controller#Action",
          "   foo GET  /foo(.:format)    redirect(301, /foo/bar) #{{ subdomain: "admin" }}",
          "   bar GET  /bar(.:format)    redirect(307, path: /foo/bar)",
          "foobar GET  /foobar(.:format) redirect(301)"
        ], output
      end

      def test_routes_can_be_filtered
        output = draw(grep: "posts") do
          resources :articles
          resources :posts
        end

        assert_equal ["   Prefix Verb   URI Pattern               Controller#Action",
                      "    posts GET    /posts(.:format)          posts#index",
                      "          POST   /posts(.:format)          posts#create",
                      " new_post GET    /posts/new(.:format)      posts#new",
                      "edit_post GET    /posts/:id/edit(.:format) posts#edit",
                      "     post GET    /posts/:id(.:format)      posts#show",
                      "          PATCH  /posts/:id(.:format)      posts#update",
                      "          PUT    /posts/:id(.:format)      posts#update",
                      "          DELETE /posts/:id(.:format)      posts#destroy"], output
      end

      def test_search_matches_literal_route_metadata_without_recognising_paths
        routes = collect(search: "/photos/:id(.:format)") do
          resources :photos
        end

        assert_equal %w[show update update destroy], routes.map { |route| route[:reqs].split("#").last }

        routes = collect(search: "/photos/7") do
          resources :photos
        end

        assert_empty routes
      end

      def test_search_treats_regular_expression_metacharacters_literally
        routes = collect(search: "[") do
          get "/photos", to: "photos#index"
        end

        assert_empty routes
      end

      def test_search_matches_constraints_and_source_locations
        ActionDispatch::Routing::Mapper.route_source_locations = true

        routes = collect(search: "A-Z") do
          get "/photos/:id", to: "photos#show", id: /[A-Z]\d{5}/
        end
        assert_equal [{ id: /[A-Z]\d{5}/ }], routes.map { |route| route[:constraints] }

        routes = collect(search: "inspector_test.rb") do
          get "/photos/:id", to: "photos#show"
        end
        assert_equal ["photos#show"], routes.map { |route| route[:reqs] }
      ensure
        ActionDispatch::Routing::Mapper.route_source_locations = false
      end

      def test_field_selectors_are_anded
        routes = collect(controller: "Admin::AuditsController", verb: "POST", action: "create") do
          get "/admin/audits", to: "admin/audits#index"
          post "/admin/audits", to: "admin/audits#create"
          post "/admin/events", to: "admin/events#create"
        end

        assert_equal ["admin/audits#create"], routes.map { |route| route[:reqs] }
      end

      def test_field_selectors_support_regular_expression_and_exact_matching
        routes = collect(name: "audit_export", exact: true) do
          get "/audit_exports", to: "audit_exports#index", as: :audit_export
          get "/audit_exports/preview", to: "audit_exports#preview", as: :audit_export_preview
        end
        assert_equal ["audit_export"], routes.map { |route| route[:name] }

        routes = collect(action: "^creat", regex: true) do
          get "/audits", to: "audits#index"
          post "/audits", to: "audits#create"
        end
        assert_equal ["audits#create"], routes.map { |route| route[:reqs] }
      end

      def test_controller_selector_canonicalises_literals_and_preserves_raw_regular_expressions
        routes = collect(controller: "Admin::AuditsController") do
          get "/admin/audits", to: "admin/audits#index"
        end
        assert_equal ["admin/audits#index"], routes.map { |route| route[:reqs] }

        routes = collect(controller: "admin/.*") do
          get "/admin/audits", to: "admin/audits#index"
        end
        assert_empty routes

        routes = collect(controller: "^admin/.*$", regex: true) do
          get "/admin/audits", to: "admin/audits#index"
        end
        assert_equal ["admin/audits#index"], routes.map { |route| route[:reqs] }
      end

      def test_exact_verb_matches_the_complete_verb_field
        routes = collect(verb: "PUT", exact: true) do
          match "/articles/:id", to: "articles#update", via: [:put, :patch]
        end
        assert_empty routes

        routes = collect(verb: "PUT|PATCH", exact: true) do
          match "/articles/:id", to: "articles#update", via: [:put, :patch]
        end
        assert_equal ["PUT|PATCH"], routes.map { |route| route[:verb] }
      end

      def test_recognition_is_independent_and_combines_with_field_selectors
        routes = collect(recognize: "/photos/7", verb: "GET") do
          resources :photos
          get "*path", to: "fallback#show"
        end

        assert_equal ["photos#show", "fallback#show"], routes.map { |route| route[:reqs] }

        routes = collect(recognize: "/photos/7", verb: "POST") do
          resources :photos
          get "*path", to: "fallback#show"
        end

        assert_empty routes
      end

      def test_legacy_grep_unions_metadata_search_and_path_recognition
        routes = collect(grep: "posts") do
          get "/posts", to: "posts#index"
          get "/articles/:id", to: "articles#show"
          get "/events", to: "events#index"
        end
        assert_equal ["posts#index"], routes.map { |route| route[:reqs] }

        routes = collect(grep: "/articles/7") do
          get "/posts", to: "posts#index"
          get "/articles/:id", to: "articles#show"
          get "/events", to: "events#index"
        end
        assert_equal ["articles#show"], routes.map { |route| route[:reqs] }
      end

      def test_new_selectors_have_a_generic_no_routes_message
        output = draw(name: "missing") do
          get "/photos", to: "photos#index"
        end

        assert_equal [
          "No routes matched the supplied selectors.",
          "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html."
        ], output
      end

      def test_json_formatter_outputs_structured_route_data
        ActionDispatch::Routing::Mapper.route_source_locations = true

        output = render(ConsoleFormatter::JSON.new) do
          get "/photos/:id", to: "photos#show", as: :photo, id: /[A-Z]\d{5}/
          get "/health", to: proc { [200, {}, ["OK"]] }
          get "/old", to: redirect("/new")
        end
        routes = ::JSON.parse(output)

        assert_equal %w[name verb path controller action endpoint constraints source_location engine], routes.first.keys

        photo = routes.find { |route| route["name"] == "photo" }
        assert_equal "GET", photo["verb"]
        assert_equal "/photos/:id(.:format)", photo["path"]
        assert_equal "photos", photo["controller"]
        assert_equal "show", photo["action"]
        assert_equal "photos#show", photo["endpoint"]
        assert_equal({ "id" => "/[A-Z]\\d{5}/" }, photo["constraints"])
        assert_match(/inspector_test\.rb/, photo.dig("source_location", "file"))
        assert_kind_of Integer, photo.dig("source_location", "line")
        assert_nil photo["engine"]

        health = routes.find { |route| route["name"] == "health" }
        assert_nil health["controller"]
        assert_nil health["action"]
        assert_equal "Inline handler (Proc/Lambda)", health["endpoint"]

        old = routes.find { |route| route["name"] == "old" }
        assert_equal "redirect(301, /new)", old["endpoint"]
      ensure
        ActionDispatch::Routing::Mapper.route_source_locations = false
      end

      def test_json_formatter_flattens_engine_routes_with_engine_provenance
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        engine.routes.draw do
          get "/cart", to: "cart#show"
        end

        output = render(ConsoleFormatter::JSON.new) do
          mount engine => "/blog", as: :blog
        end
        routes = ::JSON.parse(output)

        mount = routes.find { |route| route["name"] == "blog" }
        assert_equal "Blog::Engine", mount["endpoint"]
        assert_nil mount["engine"]

        cart = routes.find { |route| route["name"] == "cart" }
        assert_equal "cart#show", cart["endpoint"]
        assert_equal "Blog::Engine", cart["engine"]
      end

      def test_json_formatter_outputs_an_empty_array_without_human_messages
        assert_equal "[]", render(ConsoleFormatter::JSON.new) { }
        output = render(ConsoleFormatter::JSON.new, name: "missing") do
          get "/photos", to: "photos#index"
        end
        assert_equal "[]", output
      end

      def test_tsv_formatter_uses_the_json_schema_and_encodes_structured_fields
        ActionDispatch::Routing::Mapper.route_source_locations = true

        output = render(ConsoleFormatter::TSV.new) do
          get "/photos/:id", to: "photos#show", as: :photo, id: /[A-Z]\d{5}/
        end
        rows = output.lines.map { |line| line.chomp.split("\t", -1) }
        headers = rows.first
        route = headers.zip(rows.second.map { |value| unescape_tsv(value) }).to_h

        assert_equal ConsoleFormatter::Structured::FIELDS.map(&:to_s), headers
        assert_equal "photo", route["name"]
        assert_equal "photos#show", route["endpoint"]
        assert_equal({ "id" => "/[A-Z]\\d{5}/" }, ::JSON.parse(route["constraints"]))
        assert_match %r{\A.+inspector_test\.rb:\d+\z}, route["source_location"]
      ensure
        ActionDispatch::Routing::Mapper.route_source_locations = false
      end

      def test_tsv_formatter_outputs_only_the_header_without_routes
        output = render(ConsoleFormatter::TSV.new) { }

        assert_equal "name\tverb\tpath\tcontroller\taction\tendpoint\tconstraints\tsource_location\tengine\n", output
      end

      def test_routes_when_expanded
        ActionDispatch::Routing::Mapper.route_source_locations = true
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        file_name = ActiveSupport::BacktraceCleaner.new.clean([__FILE__]).first
        lineno = __LINE__
        engine.routes.draw do
          get "/cart", to: "cart#show"
        end

        output = draw(formatter: ActionDispatch::Routing::ConsoleFormatter::Expanded.new(width: 23)) do
          get "/custom/assets", to: "custom_assets#show"
          get "/custom/furnitures", to: "custom_furnitures#show"
          mount engine => "/blog", :as => "blog"
        end

        expected = [ "[ Routes for application ]",
                     "--[ Route 1 ]----------",
                     "Prefix            | custom_assets",
                     "Verb              | GET",
                     "URI               | /custom/assets(.:format)",
                     "Controller#Action | custom_assets#show",
                     "Source Location   | #{file_name}:#{lineno + 6}",
                     "--[ Route 2 ]----------",
                     "Prefix            | custom_furnitures",
                     "Verb              | GET",
                     "URI               | /custom/furnitures(.:format)",
                     "Controller#Action | custom_furnitures#show",
                     "Source Location   | #{file_name}:#{lineno + 7}",
                     "--[ Route 3 ]----------",
                     "Prefix            | blog",
                     "Verb              | ",
                     "URI               | /blog",
                     "Controller#Action | Blog::Engine",
                     "Source Location   | #{file_name}:#{lineno + 8}",
                     "",
                     "[ Routes for Blog::Engine ]",
                     "--[ Route 1 ]----------",
                     "Prefix            | cart",
                     "Verb              | GET",
                     "URI               | /cart(.:format)",
                     "Controller#Action | cart#show",
                     "Source Location   | #{file_name}:#{lineno + 2}"]

        assert_equal expected, output
      ensure
        ActionDispatch::Routing::Mapper.route_source_locations = false
      end

      def test_no_routes_matched_filter_when_expanded
        output = draw(grep: "rails/dummy", formatter: ActionDispatch::Routing::ConsoleFormatter::Expanded.new) do
          get "photos/:id" => "photos#show", :id => /[A-Z]\d{5}/
        end

        assert_equal [
          "No routes were found for this grep pattern.",
          "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html."
        ], output
      end

      def test_not_routes_when_expanded
        output = draw(formatter: ActionDispatch::Routing::ConsoleFormatter::Expanded.new) { }

        assert_equal [
          "You don't have any routes defined!",
          "",
          "Please add some routes in config/routes.rb.",
          "",
          "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html."
        ], output
      end

      def test_routes_can_be_filtered_with_namespaced_controllers
        output = draw(grep: "admin/posts") do
          resources :articles
          namespace :admin do
            resources :posts
          end
        end

        assert_equal ["         Prefix Verb   URI Pattern                     Controller#Action",
                      "    admin_posts GET    /admin/posts(.:format)          admin/posts#index",
                      "                POST   /admin/posts(.:format)          admin/posts#create",
                      " new_admin_post GET    /admin/posts/new(.:format)      admin/posts#new",
                      "edit_admin_post GET    /admin/posts/:id/edit(.:format) admin/posts#edit",
                      "     admin_post GET    /admin/posts/:id(.:format)      admin/posts#show",
                      "                PATCH  /admin/posts/:id(.:format)      admin/posts#update",
                      "                PUT    /admin/posts/:id(.:format)      admin/posts#update",
                      "                DELETE /admin/posts/:id(.:format)      admin/posts#destroy"], output
      end

      def test_regression_route_with_controller_regexp
        output = draw do
          ActionDispatch.deprecator.silence do
            get ":controller(/:action)", controller: /api\/[^\/]+/, format: false
          end
        end

        assert_equal ["Prefix Verb URI Pattern            Controller#Action",
                      "       GET  /:controller(/:action) :controller#:action"], output
      end

      def test_routes_with_undefined_filter
        output = draw(controller: "Rails::MissingController") do
          get "photos/:id" => "photos#show", :id => /[A-Z]\d{5}/
        end

        assert_equal [
          "No routes were found for this controller.",
          "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html."
        ], output
      end

      def test_no_routes_matched_filter
        output = draw(grep: "rails/dummy") do
          get "photos/:id" => "photos#show", :id => /[A-Z]\d{5}/
        end

        assert_equal [
          "No routes were found for this grep pattern.",
          "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html."
        ], output
      end

      def test_no_routes_were_defined
        output = draw { }

        assert_equal [
          "You don't have any routes defined!",
          "",
          "Please add some routes in config/routes.rb.",
          "",
          "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html."
        ], output
      end

      def test_displaying_routes_for_internal_engines
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        engine.routes.draw do
          get "/cart", to: "cart#show"
          post "/cart", to: "cart#create"
          patch "/cart", to: "cart#update"
        end

        output = draw do
          get "/custom/assets", to: "custom_assets#show"
          mount engine => "/blog", as: "blog", internal: true
        end

        assert_equal [
          "       Prefix Verb URI Pattern              Controller#Action",
          "custom_assets GET  /custom/assets(.:format) custom_assets#show",
        ], output
      end

      def test_route_with_proc_handler
        output = draw do
          get "/health", to: proc { [200, {}, ["OK"]] }
        end
        assert_equal [
          "Prefix Verb URI Pattern       Controller#Action",
          "health GET  /health(.:format) Inline handler (Proc/Lambda)"
        ], output
      end

      def test_displaying_routes_for_engines_with_filter
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        engine.routes.draw do
          get "/cart", to: "cart#show"
        end

        output = draw(grep: "cart") do
          get "/custom/assets", to: "custom_assets#show"
          mount engine => "/blog", :as => "blog"
        end

        assert_equal [
          "Routes for application:",
          "No routes were found for this grep pattern.",
          "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html.",
          "",
          "Routes for Blog::Engine:",
          "Prefix Verb URI Pattern     Controller#Action",
          "  cart GET  /cart(.:format) cart#show"
        ], output
      end

      def test_displaying_routes_for_engines_with_filter_not_matched
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        engine.routes.draw do
          get "/cart", to: "cart#show"
        end

        output = draw(grep: "dummy") do
          get "/custom/assets", to: "custom_assets#show"
          mount engine => "/blog", :as => "blog"
        end

        assert_equal [
          "Routes for application:",
          "No routes were found for this grep pattern.",
          "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html.",
          "",
          "Routes for Blog::Engine:",
          "No routes were found for this grep pattern.",
        ], output
      end

      def test_action_source_location_for_controller_action
        @set.draw do
          get "/posts", to: "inspector_test_app/posts#index"
          get "/posts/:id", to: "inspector_test_app/posts#show"
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        posts_index = routes.find { |r| r.reqs == "inspector_test_app/posts#index" }
        posts_show = routes.find { |r| r.reqs == "inspector_test_app/posts#show" }

        assert_match(/inspector_test\.rb:\d+/, posts_index.action_source_location)
        assert_match(/inspector_test\.rb:\d+/, posts_show.action_source_location)
        assert_not_equal posts_index.action_source_location, posts_show.action_source_location
      end

      def test_action_source_location_for_namespaced_controller
        @set.draw do
          get "/admin/users", to: "inspector_test_app/admin/users#index"
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        admin_users_index = routes.find { |r| r.reqs == "inspector_test_app/admin/users#index" }

        assert_match(/inspector_test\.rb:\d+/, admin_users_index.action_source_location)
      end

      def test_action_source_location_returns_nil_for_missing_controller
        @set.draw do
          get "/missing", to: "missing#index"
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        missing = routes.find { |r| r.reqs == "missing#index" }

        assert_nil missing.action_source_location
      end

      def test_action_source_location_returns_nil_for_missing_action
        @set.draw do
          get "/posts/missing", to: "inspector_test_app/posts#missing"
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        missing = routes.find { |r| r.reqs == "inspector_test_app/posts#missing" }

        assert_nil missing.action_source_location
      end

      def test_action_source_location_returns_nil_for_rack_app
        @set.draw do
          get "/health", to: proc { [200, {}, ["OK"]] }
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        health = routes.first

        assert_nil health.action_source_location
      end

      def test_action_source_location_returns_nil_for_dynamic_controller
        @set.draw do
          ActionDispatch.deprecator.silence do
            get ":controller/:action"
          end
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        dynamic = routes.first

        assert_nil dynamic.action_source_location
      end

      def test_action_source_location_included_in_to_h
        @set.draw do
          get "/posts", to: "inspector_test_app/posts#index"
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        hash = routes.first.to_h

        assert hash.key?(:action_source_location)
        assert_match(/inspector_test\.rb:\d+/, hash[:action_source_location])

        assert hash.key?(:action_source_file)
        assert_match(/inspector_test\.rb/, hash[:action_source_file])

        assert hash.key?(:action_source_line)
        assert_kind_of Integer, hash[:action_source_line]

        assert_equal "inspector_test_app/posts", hash[:controller]
        assert_equal "index", hash[:action]
        assert_equal "inspector_test_app/posts#index", hash[:endpoint]
        assert_equal({}, hash[:constraints])
      end

      def test_action_source_file_and_line_returns_tuple
        @set.draw do
          get "/posts", to: "inspector_test_app/posts#index"
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        route = routes.find { |r| r.reqs == "inspector_test_app/posts#index" }
        file, line = route.action_source_file_and_line

        assert_match(/inspector_test\.rb/, file)
        assert_kind_of Integer, line
      end

      def test_action_source_file_and_line_returns_nil_for_missing_action
        @set.draw do
          get "/posts/missing", to: "inspector_test_app/posts#missing"
        end

        routes = @set.routes.routes.map { |r| RouteWrapper.new(r) }
        route = routes.find { |r| r.reqs == "inspector_test_app/posts#missing" }

        assert_nil route.action_source_file_and_line
      end

      def test_action_source_location_in_expanded_output
        @set.draw do
          get "/posts", to: "inspector_test_app/posts#index"
        end

        inspector = RoutesInspector.new(@set.routes)
        output = inspector.format(ConsoleFormatter::Expanded.new(width: 23))

        assert_match(/Action Location.*inspector_test\.rb:\d+/m, output)
      end

      private
        def unescape_tsv(value)
          if value.start_with?('"') && value.end_with?('"')
            value[1...-1].gsub('""', '"')
          else
            value
          end
        end

        def render(formatter, **options, &block)
          @set.draw(&block)
          inspector = ActionDispatch::Routing::RoutesInspector.new(@set.routes)
          inspector.format(formatter, options)
        end

        def collect(**options, &block)
          @set.draw(&block)
          inspector = ActionDispatch::Routing::RoutesInspector.new(@set.routes)
          inspector.format(RouteCollector.new, options)
        end

        def draw(formatter: ActionDispatch::Routing::ConsoleFormatter::Sheet.new, **options, &block)
          @set.draw(&block)
          inspector = ActionDispatch::Routing::RoutesInspector.new(@set.routes)
          inspector.format(formatter, options).split("\n")
        end
    end
  end
end
