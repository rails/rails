# frozen_string_literal: true

require "abstract_unit"

class PermissionsPolicyTest < ActiveSupport::TestCase
  def setup
    @policy = ActionDispatch::PermissionsPolicy.new
  end

  def test_mappings
    @policy.midi :self
    assert_equal "midi 'self'", @policy.build

    @policy.midi :none
    assert_equal "midi 'none'", @policy.build
  end

  def test_multiple_sources_for_a_single_directive
    @policy.geolocation :self, "https://example.com"
    assert_equal "geolocation 'self' https://example.com", @policy.build
  end

  def test_single_directive_for_multiple_directives
    @policy.geolocation :self
    @policy.usb :none
    assert_equal "geolocation 'self'; usb 'none'", @policy.build
  end

  def test_multiple_directives_for_multiple_directives
    @policy.geolocation :self, "https://example.com"
    @policy.usb :none, "https://example.com"
    assert_equal "geolocation 'self' https://example.com; usb 'none' https://example.com", @policy.build
  end

  def test_invalid_directive_source
    exception = assert_raises(ArgumentError) do
      @policy.geolocation [:non_existent]
    end

    assert_equal "Invalid HTTP permissions policy source: [:non_existent]", exception.message
  end
end

class PermissionsPolicyMiddlewareTest < ActionDispatch::IntegrationTest
  APP = ->(env) { [200, {}, []] }

  POLICY = ActionDispatch::PermissionsPolicy.new do |p|
    p.gyroscope :self
  end

  class PolicyConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.permissions_policy"] = POLICY
      env["action_dispatch.show_exceptions"] = :none

      @app.call(env)
    end
  end

  test "html requests will set a policy" do
    @app = build_app(->(env) { [200, { Rack::CONTENT_TYPE => "text/html" }, []] })

    get "/index"

    assert_equal "gyroscope 'self'", response.headers[ActionDispatch::Constants::FEATURE_POLICY]
  end

  test "non-html requests will set a policy" do
    @app = build_app(->(env) { [200, { Rack::CONTENT_TYPE => "application/json" }, []] })

    get "/index"

    assert_equal "gyroscope 'self'", response.headers[ActionDispatch::Constants::FEATURE_POLICY]
  end

  test "existing policies will not be overwritten" do
    @app = build_app(->(env) { [200, { ActionDispatch::Constants::FEATURE_POLICY => "gyroscope 'none'" }, []] })

    get "/index"

    assert_equal "gyroscope 'none'", response.headers[ActionDispatch::Constants::FEATURE_POLICY]
  end

  private
    def build_app(app)
      PolicyConfigMiddleware.new(
        Rack::Lint.new(
          ActionDispatch::PermissionsPolicy::Middleware.new(
            Rack::Lint.new(app),
          ),
        ),
      )
    end
end

class PermissionsPolicyIntegrationTest < ActionDispatch::IntegrationTest
  class PolicyController < ActionController::Base
    permissions_policy only: :index do |f|
      f.gyroscope :none
    end

    permissions_policy only: :sample_controller do |f|
      f.gyroscope nil
      f.usb       :self
    end

    permissions_policy only: :multiple_directives do |f|
      f.gyroscope nil
      f.usb       :self
      f.autoplay  "https://example.com"
      f.payment   "https://secure.example.com"
    end

    def index
      head :ok
    end

    def sample_controller
      head :ok
    end

    def multiple_directives
      head :ok
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "permissions_policy_integration_test" do
      get "/", to: "policy#index"
      get "/sample_controller", to: "policy#sample_controller"
      get "/multiple_directives", to: "policy#multiple_directives"
    end
  end

  POLICY = ActionDispatch::PermissionsPolicy.new do |p|
    p.gyroscope :self
  end

  class PolicyConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.permissions_policy"] = POLICY
      env["action_dispatch.show_exceptions"] = :none

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use PolicyConfigMiddleware
    middleware.use Rack::Lint
    middleware.use ActionDispatch::PermissionsPolicy::Middleware
    middleware.use Rack::Lint
  end

  def app
    APP
  end

  def test_generates_permissions_policy_header
    get "/"
    assert_policy "gyroscope 'none'"
  end

  def test_generates_per_controller_permissions_policy_header
    get "/sample_controller"
    assert_policy "usb 'self'"
  end

  def test_generates_multiple_directives_permissions_policy_header
    get "/multiple_directives"
    assert_policy "usb 'self'; autoplay https://example.com; payment https://secure.example.com"
  end

  private
    def assert_policy(expected)
      assert_response :success
      assert_equal expected, response.headers["Feature-Policy"]
    end
end

class PermissionsPolicyWithHelpersIntegrationTest < ActionDispatch::IntegrationTest
  module ApplicationHelper
    def pigs_can_fly?
      false
    end
  end

  class ApplicationController < ActionController::Base
    helper_method :sky_is_blue?
    def sky_is_blue?
      true
    end
  end

  class PolicyController < ApplicationController
    permissions_policy do |f|
      f.gyroscope :none  unless helpers.pigs_can_fly?
      f.usb       :self  if helpers.sky_is_blue?
    end

    def index
      head :ok
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "permissions_policy_with_helpers_integration_test" do
      get "/", to: "policy#index"
    end
  end

  POLICY = ActionDispatch::PermissionsPolicy.new do |p|
    p.gyroscope :self
  end

  class PolicyConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.permissions_policy"] = POLICY
      env["action_dispatch.show_exceptions"] = :none

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use PolicyConfigMiddleware
    middleware.use Rack::Lint
    middleware.use ActionDispatch::PermissionsPolicy::Middleware
    middleware.use Rack::Lint
  end

  def app
    APP
  end

  def test_generates_permissions_policy_header
    get "/"
    assert_policy "gyroscope 'none'; usb 'self'"
  end

  private
    def assert_policy(expected)
      assert_response :success
      assert_equal expected, response.headers[ActionDispatch::Constants::FEATURE_POLICY]
    end
end
