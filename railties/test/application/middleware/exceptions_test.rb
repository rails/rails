# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class MiddlewareExceptionsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "show exceptions middleware filter backtrace before logging" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            raise 'oops'
          end
        end
      RUBY

      log = capture(:stdout) do
        get("/foo", {}, "HTTPS" => "on")
        assert_equal 500, last_response.status
      end

      assert_no_match(/action_dispatch/, log, log)
      assert_match(/oops/, log, log)
    end

    test "renders active record exceptions as 404" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            raise ActiveRecord::RecordNotFound
          end
        end
      RUBY

      get "/foo", {}, { "HTTPS" => "on" }
      assert_equal 404, last_response.status
    end

    test "renders unknown http methods as 405" do
      request("/", { "REQUEST_METHOD" => "NOT_AN_HTTP_METHOD", "HTTPS" => "on" })
      assert_equal 405, last_response.status
    end

    test "renders and evaluated a 422 erb page" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def root
            raise ActionController::InvalidAuthenticityToken
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "foo#root"
        end
      RUBY

      app_file "public/422.html.erb", <<-RUBY
        <%= stylesheet_link_tag("application") %>
        Return to the <%= link_to("home page", root_path) %>
      RUBY

      get "/", {}, { "HTTPS" => "on" }
      assert_equal 422, last_response.status
      assert_match('<link rel="stylesheet" href="/assets/application', last_response.body)
      assert_match('Return to the <a href="/">home page</a>', last_response.body)
    end

    test "renders a 406 page when an invalid content-type and accept header are passed" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def root
            raise ActionController::InvalidAuthenticityToken
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "foo#root"
        end
      RUBY

      app_file "public/406.html.erb", <<-RUBY
        <%= stylesheet_link_tag("application") %>
        Return to the <%= link_to("home page", root_path) %>
      RUBY

      get "/", {}, { "HTTP_ACCEPT" => "invalid", "CONTENT_TYPE" => "invalid", "HTTPS" => "on" }
      assert_equal 406, last_response.status
      assert_match('<link rel="stylesheet" href="/assets/application', last_response.body)
      assert_match('Return to the <a href="/">home page</a>', last_response.body)
    end

    test "add responde headers with a middleware before sending the response" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def root
            head(:ok)
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "foo#root"
        end
      RUBY

      add_to_config(<<~CODE)
        my_middleware = Class.new do
          def initialize(app)
            @app = app
          end

          def call(env)
            result = @app.call(env)
            result[1]["some-header"] = "foo"
            result
          end
        end

        ActionDispatch::ExceptionsController.use(my_middleware)
      CODE

      get "/abc", {}, { "HTTPS" => "on" }
      assert_equal 404, last_response.status
      assert_equal("foo", last_response.headers["some-header"])

      get "/", {}, { "HTTPS" => "on" }
      assert_equal 200, last_response.status
      assert_not(last_response.headers.key?("some-header"))
    end

    test "renders unknown http methods as 405 when routes are used as the custom exceptions app" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
        end
      RUBY

      add_to_config "config.exceptions_app = self.routes"

      app.config.action_dispatch.show_exceptions = :all

      request "/", { "REQUEST_METHOD" => "NOT_AN_HTTP_METHOD", "HTTPS" => "on" }
      assert_equal 405, last_response.status
    end

    test "renders unknown http formats as 406 when routes are used as the custom exceptions app" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            render plain: "rendering index!"
          end

          def not_acceptable
            render json: { error: "some error message" }, status: :not_acceptable
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get "/foo", to: "foo#index"
          post "/foo", to: "foo#index"
          match "/406", to: "foo#not_acceptable", via: :all
        end
      RUBY

      add_to_config "config.exceptions_app = self.routes"
      add_to_config "config.action_dispatch.show_exceptions = :all"
      add_to_config "config.consider_all_requests_local = false"

      get "/foo", {}, { "HTTP_ACCEPT" => "invalid", "HTTPS" => "on" }
      assert_equal 406, last_response.status
      assert_not_equal "rendering index!", last_response.body

      get "/foo", {}, { "CONTENT_TYPE" => "invalid", "HTTPS" => "on" }
      assert_equal 406, last_response.status
      assert_not_equal "rendering index!", last_response.body

      get "/foo", {}, { "HTTP_ACCEPT" => "invalid", "CONTENT_TYPE" => "invalid", "HTTPS" => "on" }
      assert_equal 406, last_response.status
      assert_not_equal "rendering index!", last_response.body

      post "/foo", {}, { "HTTP_ACCEPT" => "invalid", "CONTENT_TYPE" => "invalid", "HTTPS" => "on" }
      assert_equal 406, last_response.status
      assert_not_equal "rendering index!", last_response.body
    end

    test "uses custom exceptions app" do
      add_to_config <<-RUBY
        config.exceptions_app = lambda do |env|
          [404, { "Content-Type" => "text/plain" }, ["YOU FAILED"]]
        end
      RUBY

      app.config.action_dispatch.show_exceptions = :all

      get("/foo", {}, "HTTPS" => "on")
      assert_equal 404, last_response.status
      assert_equal "YOU FAILED", last_response.body
    end

    test "URL generation error when action_dispatch.show_exceptions is set raises an exception" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            raise ActionController::UrlGenerationError
          end
        end
      RUBY

      app.config.action_dispatch.show_exceptions = :all

      get("/foo", {}, "HTTPS" => "on")
      assert_equal 500, last_response.status
    end

    test "unspecified route when action_dispatch.show_exceptions is not set raises an exception" do
      app.config.action_dispatch.show_exceptions = :none

      assert_raise(ActionController::RoutingError) do
        get("/foo", {}, "HTTPS" => "on")
      end
    end

    test "unspecified route when action_dispatch.show_exceptions is set shows 404" do
      app.config.action_dispatch.show_exceptions = :all

      assert_nothing_raised do
        get("/foo", {}, "HTTPS" => "on")
        assert_match "The page you were looking for doesn't exist.", last_response.body
      end
    end

    test "unspecified route when action_dispatch.show_exceptions and consider_all_requests_local are set shows diagnostics" do
      app.config.action_dispatch.show_exceptions = :all
      app.config.consider_all_requests_local = true

      assert_nothing_raised do
        get("/foo", {}, "HTTPS" => "on")
        assert_match "No route matches", last_response.body
      end
    end

    test "routing to a nonexistent controller when action_dispatch.show_exceptions and consider_all_requests_local are set shows diagnostics" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          resources :articles
        end
      RUBY

      app.config.action_dispatch.show_exceptions = :all
      app.config.consider_all_requests_local = true

      get("/articles", {}, "HTTPS" => "on")
      assert_match "<title>Action Controller: Exception caught</title>", last_response.body
    end

    test "displays diagnostics message when exception raised in template that contains UTF-8" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
          end
        end
      RUBY

      app.config.action_dispatch.show_exceptions = :all
      app.config.consider_all_requests_local = true

      app_file "app/views/foo/index.html.erb", <<-ERB
        <% raise 'boooom' %>
        ✓測試テスト시험
      ERB

      get("/foo", { utf8: "✓" }, { "HTTPS" => "on" })
      assert_match(/boooom/, last_response.body)
      assert_match(/測試テスト시험/, last_response.body)
    end

    test "displays diagnostics message when malformed query parameters are provided" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
          end
        end
      RUBY

      app.config.action_dispatch.show_exceptions = :all
      app.config.consider_all_requests_local = true

      get "/foo?x[y]=1&x[y][][w]=2", {}, "HTTPS" => "on"
      assert_equal 400, last_response.status
      assert_match "Invalid query parameters", last_response.body
    end

    test "displays diagnostics message when too deep query parameters are provided" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
          end
        end
      RUBY

      app.config.action_dispatch.show_exceptions = :all
      app.config.consider_all_requests_local = true

      limit = ActionDispatch::ParamBuilder.default.param_depth_limit + 1
      malicious_url = "/foo?#{'[test]' * limit}=test"

      get(malicious_url, {}, "HTTPS" => "on")
      assert_equal 400, last_response.status
      assert_match "Invalid query parameters", last_response.body
    end

    test "displays statement invalid template correctly" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            raise ActiveRecord::StatementInvalid
          end
        end
      RUBY
      app.config.action_dispatch.show_exceptions = :all
      app.config.consider_all_requests_local = true
      app.config.action_dispatch.ignore_accept_header = false

      get("/foo", {}, "HTTPS" => "on")
      assert_equal 500, last_response.status
      assert_match "<title>Action Controller: Exception caught</title>", last_response.body
      assert_match "ActiveRecord::StatementInvalid", last_response.body

      get "/foo", {}, { "HTTP_ACCEPT" => "text/plain", "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest", "HTTPS" => "on" }
      assert_equal 500, last_response.status
      assert_equal "text/plain", last_response.media_type
      assert_match "ActiveRecord::StatementInvalid", last_response.body
    end

    test "show_exceptions :rescuable with a rescuable error" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            raise AbstractController::ActionNotFound
          end
        end
      RUBY

      app.config.action_dispatch.show_exceptions = :rescuable

      get "/foo", {}, { "HTTPS" => "on" }
      assert_equal 404, last_response.status
    end

    test "show_exceptions :rescuable with a non-rescuable error" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            raise 'oops'
          end
        end
      RUBY

      app.config.action_dispatch.show_exceptions = :rescuable

      error = assert_raises(RuntimeError) { get("/foo", {}, { "HTTPS" => "on" }) }
      assert_equal "oops", error.message
    end
  end
end
