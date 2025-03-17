# frozen_string_literal: true

require "abstract_unit"

class ReportingEndpointsTest < ActiveSupport::TestCase
  def setup
    @reporting_endpoints = ActionDispatch::ReportingEndpoints.new
  end

  def test_build
    @reporting_endpoints.endpoints = { "csp-reports": "https://example.pizza" }
    assert_equal "csp-reports=\"https://example.pizza\"", @reporting_endpoints.build
  end

  def test_multiple_endpoints_accepted
    @reporting_endpoints.endpoints = {
      "csp-reports": "https://business.pizza",
      "other-reports": "https://something.else"
    }

    assert_equal "csp-reports=\"https://business.pizza\", other-reports=\"https://something.else\"", @reporting_endpoints.build
  end

  def test_duplicate_endpoints
    @reporting_endpoints.endpoints = {
      "csp-reports": "https://business.pizza",
      "csp-reports": "https://business.second",
    }

    assert_equal "csp-reports=\"https://business.second\"", @reporting_endpoints.build
  end
end

class ReportingEndpointsMiddlewareTest < ActiveSupport::TestCase
  def setup
    @env = Rack::MockRequest.env_for("", {})
    @env["action_dispatch.reporting_endpoints"] = ActionDispatch::ReportingEndpoints.new do |e|
      e.endpoints = { "csp-reports": "https://override.biz" }
    end

    @default_endpoints = "csp-reports=\"https://example.biz\""
  end

  def test_rack_lint
    app = proc { [200, {}, []] }

    assert_nothing_raised do
      Rack::Lint.new(
        ActionDispatch::ReportingEndpoints::Middleware.new(
          Rack::Lint.new(app)
        )
      ).call(@env)
    end
  end

  def test_does_not_override_app_reporting_endpoints
    app = proc { [200, { ActionDispatch::Constants::REPORTING_ENDPOINTS => @default_endpoints }, []] }
    _, headers, _ = Rack::Lint.new(
      ActionDispatch::ReportingEndpoints::Middleware.new(Rack::Lint.new(app))
    ).call(@env)

    assert_equal @default_endpoints, headers[ActionDispatch::Constants::REPORTING_ENDPOINTS]
  end
end

class DefaultReportingEndpointsIntegrationTest < ActionDispatch::IntegrationTest
  class HeaderController < ActionController::Base
    def index
      head :ok
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "default_reporting_endpoints_integration_test" do
      get "/", to: "header#index"
      get "/redirect", to: redirect("/")
    end
  end

  HEADER = ActionDispatch::ReportingEndpoints.new do |e|
    e.endpoints = { "csp-reports": "https://example.biz" }
  end

  class HeaderConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.reporting_endpoints"] = HEADER

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use Rack::Lint
    middleware.use HeaderConfigMiddleware
    middleware.use ActionDispatch::ReportingEndpoints::Middleware
    middleware.use Rack::Lint
  end

  def app
    APP
  end

  def test_reporting_headers_served
    get "/"
    assert_equal "csp-reports=\"https://example.biz\"", response.headers["Reporting-Endpoints"]
  end

  def test_redirect_works_with_dynamic_sources
    get "/redirect"
    assert_response :redirect
    assert_equal "csp-reports=\"https://example.biz\"", response.headers["Reporting-Endpoints"]
  end
end


class ReportingEndpointsIntegrationTest < ActionDispatch::IntegrationTest
  class HeaderController < ActionController::Base
    reporting_endpoints only: :conditional, if: :condition? do |e|
      e.endpoints = { "csp-reports": "https://true.example.com" }
    end

    reporting_endpoints only: :conditional, unless: :condition? do |e|
      e.endpoints = { "csp-reports": "https://false.example.com" }
    end

    reporting_endpoints(false, only: :no_endpoints)

    def index
      head :ok
    end

    def conditional
      head :ok
    end

    def no_endpoints
      head :ok
    end

    private
      def condition?
        params[:condition] == "true"
      end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "reporting_endpoints_integration_test" do
      get "/", to: "header#index"
      get "/conditional", to: "header#conditional"
      get "/no-endpoints", to: "header#no_endpoints"
    end
  end

  HEADER = ActionDispatch::ReportingEndpoints.new do |e|
    e.endpoints = { "csp-reports": "https://example.biz" }
  end

  class HeaderConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.reporting_endpoints"] = HEADER
      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use Rack::Lint
    middleware.use HeaderConfigMiddleware
    middleware.use ActionDispatch::ReportingEndpoints::Middleware
    middleware.use Rack::Lint
  end

  def app
    APP
  end

  def test_generates_conditional_reporting_endpoints
    get "/conditional", params: { condition: "true" }
    assert_response :success
    assert_equal "csp-reports=\"https://true.example.com\"", response.headers["Reporting-Endpoints"]

    get "/conditional", params: { condition: "false" }
    assert_equal "csp-reports=\"https://false.example.com\"", response.headers["Reporting-Endpoints"]
  end

  def test_generates_no_reporting_endpoints_when_controller_opted_out
    get "/no-endpoints"
    assert_response :success
    assert_nil response.headers["Reporting-Endpoints"]
  end
end

class HelpersReportingEndpointsIntegrationTest < ActionDispatch::IntegrationTest
  class ApplicationController < ActionController::Base
    helper_method :sky_is_blue?
    def sky_is_blue?
      true
    end
  end

  class HeaderController < ApplicationController
    reporting_endpoints do |e|
      e.endpoints = { "csp-reports": "https://example.biz" } if helpers.sky_is_blue?
    end

    def index
      head :ok
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "helpers_reporting_endpoints_integration_test" do
      get "/", to: "header#index"
    end
  end

  HEADER = ActionDispatch::ReportingEndpoints.new do |e|
    e.endpoints = { "csp-reports": "https://business.biz" }
  end

  class HeaderConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.reporting_endpoints"] = HEADER

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use Rack::Lint
    middleware.use HeaderConfigMiddleware
    middleware.use ActionDispatch::ReportingEndpoints::Middleware
    middleware.use Rack::Lint
  end

  def app
    APP
  end

  def test_can_call_helper_methods_in_reporing_endpoints_block
    get "/"

    assert_response :success
    assert_match "csp-reports=\"https://example.biz\"", response.headers["Reporting-Endpoints"]
  end
end
