# frozen_string_literal: true

require "abstract_unit"

class FeaturePolicyTest < ActiveSupport::TestCase
  def setup
    @policy = ActionDispatch::FeaturePolicy.new
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
      @policy.vr [:non_existent]
    end

    assert_equal "Invalid HTTP feature policy source: [:non_existent]", exception.message
  end
end

class FeaturePolicyIntegrationTest < ActionDispatch::IntegrationTest
  class PolicyController < ActionController::Base
    feature_policy only: :index do |f|
      f.gyroscope :none
    end

    feature_policy only: :sample_controller do |f|
      f.gyroscope nil
      f.usb       :self
    end

    feature_policy only: :multiple_directives do |f|
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
    scope module: "feature_policy_integration_test" do
      get "/", to: "policy#index"
      get "/sample_controller", to: "policy#sample_controller"
      get "/multiple_directives", to: "policy#multiple_directives"
    end
  end

  POLICY = ActionDispatch::FeaturePolicy.new do |p|
    p.gyroscope :self
  end

  class PolicyConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.feature_policy"] = POLICY
      env["action_dispatch.show_exceptions"] = false

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use PolicyConfigMiddleware
    middleware.use ActionDispatch::FeaturePolicy::Middleware
  end

  def app
    APP
  end

  def test_generates_feature_policy_header
    get "/"
    assert_policy "gyroscope 'none'"
  end

  def test_generates_per_controller_feature_policy_header
    get "/sample_controller"
    assert_policy "usb 'self'"
  end

  def test_generates_multiple_directives_feature_policy_header
    get "/multiple_directives"
    assert_policy "usb 'self'; autoplay https://example.com; payment https://secure.example.com"
  end

  private

    def env_config
      Rails.application.env_config
    end

    def feature_policy
      env_config["action_dispatch.feature_policy"]
    end

    def feature_policy=(policy)
      env_config["action_dispatch.feature_policy"] = policy
    end

    def assert_policy(expected)
      assert_response :success
      assert_equal expected, response.headers["Feature-Policy"]
    end
end
