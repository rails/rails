# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module Rails
  class Engine
    class LazyRouteSetTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      setup :build_app
      teardown :teardown_app

      class UsersController < ActionController::Base
      end

      test "app lazily loads routes when invoking url helpers" do
        require "#{app_path}/config/environment"

        assert_not_operator(:root_path, :in?, app_url_helpers.methods)
        assert_equal("/", app_url_helpers.root_path)
      end

      test "engine lazily loads routes when invoking url helpers" do
        require "#{app_path}/config/environment"

        assert_not_operator(:root_path, :in?, engine_url_helpers.methods)
        assert_equal("/plugin/", engine_url_helpers.root_path)
      end

      test "app lazily loads routes when checking respond_to?" do
        require "#{app_path}/config/environment"

        assert_not_operator(:root_path, :in?, app_url_helpers.methods)
        assert_operator(app_url_helpers, :respond_to?, :root_path)
      end

      test "engine lazily loads routes when checking respond_to?" do
        require "#{app_path}/config/environment"

        assert_not_operator(:root_path, :in?, engine_url_helpers.methods)
        assert_operator(engine_url_helpers, :respond_to?, :root_path)
      end

      test "app lazily loads routes when making a request" do
        require "#{app_path}/config/environment"

        @app = Rails.application

        assert_not_operator(:root_path, :in?, app_url_helpers.methods)
        response = get("/")
        assert_equal(200, response.first)
      end

      test "app lazily loads routes when polymorphic_url is called" do
        app_file "test/integration/my_test.rb", <<~RUBY
          require "test_helper"

          class MyTest < ActionDispatch::IntegrationTest
            test "polymorphic_url works" do
              puts polymorphic_url(Comment.new)
            end
          end
        RUBY

        app_file "app/models/comment.rb", <<~RUBY
          class Comment
          end
        RUBY

        output = rails("test", "test/integration/my_test.rb")
        assert_match("https://example.org", output)
      end

      test "engine lazily loads routes when making a request" do
        require "#{app_path}/config/environment"

        @app = Rails.application

        assert_not_operator(:root_path, :in?, engine_url_helpers.methods)
        response = get("/plugin/")
        assert_equal(200, response.first)
      end

      test "concurrent requests during the first route load wait for routes to be fully drawn" do
        pause_route_draw

        require "#{app_path}/config/environment"

        @app = Rails.application

        first_request = Thread.new { get("/") }
        $route_draw_started.pop

        concurrent_request = Thread.new { get("/") }

        # Wait for the concurrent request to either finish (it was routed
        # against a half-drawn route set) or block until the draw completes.
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
        until !concurrent_request.alive? ||
              (concurrent_request.stop? && concurrent_request.backtrace&.any? { |frame| frame.include?("execute_unless_loaded") })
          flunk("Timed out waiting for the concurrent request") if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          Thread.pass
        end

        $route_draw_resume << true

        assert_equal(200, first_request.value.first)
        assert_equal(200, concurrent_request.value.first)
      end

      test "url helpers called while another thread draws the routes wait for the draw" do
        pause_route_draw

        require "#{app_path}/config/environment"

        helpers = app_url_helpers

        drawing = Thread.new { helpers.root_path }
        $route_draw_started.pop

        waiting = Thread.new { helpers.root_path }
        Thread.pass until waiting.stop?
        $route_draw_resume << true

        assert_equal("/", drawing.value)
        assert_equal("/", waiting.value)
      end

      test "respond_to? on url helpers called while another thread draws the routes waits for the draw" do
        pause_route_draw

        require "#{app_path}/config/environment"

        helpers = app_url_helpers

        drawing = Thread.new { helpers.root_path }
        $route_draw_started.pop

        waiting = Thread.new { helpers.respond_to?(:root_path) }
        Thread.pass until waiting.stop?
        $route_draw_resume << true

        assert_equal("/", drawing.value)
        assert(waiting.value)
      end

      test "app lazily loads routes when url_for is used" do
        require "#{app_path}/config/environment"

        @app = Rails.application

        assert_not_operator(:products_path, :in?, app_url_helpers.methods)
        assert_equal "/products", app_url_helpers.url_for(
          controller: :products, action: :index, only_path: true,
        )
        assert_operator(:products_path, :in?, app_url_helpers.methods)
      end

      test "engine lazily loads routes when url_for is used" do
        require "#{app_path}/config/environment"

        @app = Rails.application

        assert_not_operator(:plugin_posts_path, :in?, engine_url_helpers.methods)
        assert_equal "/plugin/posts", engine_url_helpers.url_for(
          controller: :posts, action: :index, only_path: true,
        )
        assert_not_operator(:plugin_posts_path, :in?, engine_url_helpers.methods)
      end

      test "railties can access lazy routes" do
        app_file("config/application.rb", <<~RUBY, "a+")

          class MyRailtie < ::Rails::Railtie
            initializer :some_railtie_init do |app|
              app.routes
            end
          end
        RUBY

        require "#{app_path}/config/environment"

        assert_operator(Rails.application.routes, :is_a?, Engine::LazyRouteSet)
      end

      test "reloads routes when recognize_path is called" do
        require "#{app_path}/config/environment"

        assert_equal(
          { controller: "rails/engine/lazy_route_set_test/users", action: "index" },
          Rails.application.routes.recognize_path("/users")
        )
      end

      test "reloads routes when recognize_path_with_request is called" do
        require "#{app_path}/config/environment"

        path = "/users"
        req = ActionDispatch::Request.new(::Rack::MockRequest.env_for(path))

        assert_equal(
          { controller: "rails/engine/lazy_route_set_test/users", action: "index" },
          Rails.application.routes.recognize_path_with_request(req, path, {})
        )
      end

      private
        # Parks the initial route draw until $route_draw_resume is signaled,
        # so a test can deterministically overlap it with other threads.
        def pause_route_draw
          app_file "config/initializers/pause_route_draw.rb", <<~RUBY
            $route_draw_started = Queue.new
            $route_draw_resume = Queue.new

            Rails.application.routes_reloader.singleton_class.prepend(Module.new do
              def load_paths
                $route_draw_started << true
                $route_draw_resume.pop
                super
              end
            end)
          RUBY
        end

        def build_app
          super

          app_file "app/models/user.rb", <<~RUBY
            class User < ActiveRecord::Base
            end
          RUBY

          app_file "config/routes.rb", <<~RUBY
            Rails.application.routes.draw do
              root to: proc { [200, {}, []] }

              resources :products
              resources :users, module: "rails/engine/lazy_route_set_test"
              resolve("Comment") { "https://example.org" }

              mount Plugin::Engine, at: "/plugin"
            end
          RUBY

          build_engine
        end

        def build_engine
          engine "plugin" do |plugin|
            plugin.write "app/models/post.rb", <<~RUBY
              class Post < ActiveRecord::Base
              end
            RUBY

            plugin.write "lib/plugin.rb", <<~RUBY
              module Plugin
                class Engine < ::Rails::Engine
                end
              end
            RUBY

            plugin.write "config/routes.rb", <<~RUBY
              Plugin::Engine.routes.draw do
                root to: proc { [200, {}, []] }

                resources(:posts)
              end
            RUBY
          end
        end

        def app_url_helpers
          Rails.application.routes.url_helpers
        end

        def engine_url_helpers
          Plugin::Engine.routes.url_helpers
        end
    end
  end
end
