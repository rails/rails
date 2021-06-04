# frozen_string_literal: true

require "abstract_unit"

class ContentSecurityPolicyTest < ActiveSupport::TestCase
  def setup
    @policy = ActionDispatch::ContentSecurityPolicy.new
  end

  def test_build
    assert_equal "", @policy.build

    @policy.script_src :self
    assert_equal "script-src 'self'", @policy.build
  end

  def test_dup
    @policy.img_src :self
    @policy.block_all_mixed_content
    @policy.upgrade_insecure_requests
    @policy.sandbox
    copied = @policy.dup
    assert_equal copied.build, @policy.build
  end

  def test_mappings
    @policy.script_src :data
    assert_equal "script-src data:", @policy.build

    @policy.script_src :mediastream
    assert_equal "script-src mediastream:", @policy.build

    @policy.script_src :blob
    assert_equal "script-src blob:", @policy.build

    @policy.script_src :filesystem
    assert_equal "script-src filesystem:", @policy.build

    @policy.script_src :self
    assert_equal "script-src 'self'", @policy.build

    @policy.script_src :unsafe_inline
    assert_equal "script-src 'unsafe-inline'", @policy.build

    @policy.script_src :unsafe_eval
    assert_equal "script-src 'unsafe-eval'", @policy.build

    @policy.script_src :none
    assert_equal "script-src 'none'", @policy.build

    @policy.script_src :strict_dynamic
    assert_equal "script-src 'strict-dynamic'", @policy.build

    @policy.script_src :ws
    assert_equal "script-src ws:", @policy.build

    @policy.script_src :wss
    assert_equal "script-src wss:", @policy.build

    @policy.script_src :none, :report_sample
    assert_equal "script-src 'none' 'report-sample'", @policy.build
  end

  def test_fetch_directives
    @policy.child_src :self
    assert_match %r{child-src 'self'}, @policy.build

    @policy.child_src false
    assert_no_match %r{child-src}, @policy.build

    @policy.connect_src :self
    assert_match %r{connect-src 'self'}, @policy.build

    @policy.connect_src false
    assert_no_match %r{connect-src}, @policy.build

    @policy.default_src :self
    assert_match %r{default-src 'self'}, @policy.build

    @policy.default_src false
    assert_no_match %r{default-src}, @policy.build

    @policy.font_src :self
    assert_match %r{font-src 'self'}, @policy.build

    @policy.font_src false
    assert_no_match %r{font-src}, @policy.build

    @policy.frame_src :self
    assert_match %r{frame-src 'self'}, @policy.build

    @policy.frame_src false
    assert_no_match %r{frame-src}, @policy.build

    @policy.img_src :self
    assert_match %r{img-src 'self'}, @policy.build

    @policy.img_src false
    assert_no_match %r{img-src}, @policy.build

    @policy.manifest_src :self
    assert_match %r{manifest-src 'self'}, @policy.build

    @policy.manifest_src false
    assert_no_match %r{manifest-src}, @policy.build

    @policy.media_src :self
    assert_match %r{media-src 'self'}, @policy.build

    @policy.media_src false
    assert_no_match %r{media-src}, @policy.build

    @policy.object_src :self
    assert_match %r{object-src 'self'}, @policy.build

    @policy.object_src false
    assert_no_match %r{object-src}, @policy.build

    @policy.prefetch_src :self
    assert_match %r{prefetch-src 'self'}, @policy.build

    @policy.prefetch_src false
    assert_no_match %r{prefetch-src}, @policy.build

    @policy.script_src :self
    assert_match %r{script-src 'self'}, @policy.build

    @policy.script_src false
    assert_no_match %r{script-src}, @policy.build

    @policy.script_src_attr :self
    assert_match %r{script-src-attr 'self'}, @policy.build

    @policy.script_src_attr false
    assert_no_match %r{script-src-attr}, @policy.build

    @policy.script_src_elem :self
    assert_match %r{script-src-elem 'self'}, @policy.build

    @policy.script_src_elem false
    assert_no_match %r{script-src-elem}, @policy.build

    @policy.style_src :self
    assert_match %r{style-src 'self'}, @policy.build

    @policy.style_src false
    assert_no_match %r{style-src}, @policy.build

    @policy.style_src_attr :self
    assert_match %r{style-src-attr 'self'}, @policy.build

    @policy.style_src_attr false
    assert_no_match %r{style-src-attr}, @policy.build

    @policy.style_src_elem :self
    assert_match %r{style-src-elem 'self'}, @policy.build

    @policy.style_src_elem false
    assert_no_match %r{style-src-elem}, @policy.build

    @policy.worker_src :self
    assert_match %r{worker-src 'self'}, @policy.build

    @policy.worker_src false
    assert_no_match %r{worker-src}, @policy.build
  end

  def test_document_directives
    @policy.base_uri "https://example.com"
    assert_match %r{base-uri https://example\.com}, @policy.build

    @policy.plugin_types "application/x-shockwave-flash"
    assert_match %r{plugin-types application/x-shockwave-flash}, @policy.build

    @policy.sandbox
    assert_match %r{sandbox}, @policy.build

    @policy.sandbox "allow-scripts", "allow-modals"
    assert_match %r{sandbox allow-scripts allow-modals}, @policy.build

    @policy.sandbox false
    assert_no_match %r{sandbox}, @policy.build
  end

  def test_navigation_directives
    @policy.form_action :self
    assert_match %r{form-action 'self'}, @policy.build

    @policy.frame_ancestors :self
    assert_match %r{frame-ancestors 'self'}, @policy.build
  end

  def test_reporting_directives
    @policy.report_uri "/violations"
    assert_match %r{report-uri /violations}, @policy.build
  end

  def test_other_directives
    @policy.block_all_mixed_content
    assert_match %r{block-all-mixed-content}, @policy.build

    @policy.block_all_mixed_content false
    assert_no_match %r{block-all-mixed-content}, @policy.build

    @policy.require_sri_for :script, :style
    assert_match %r{require-sri-for script style}, @policy.build

    @policy.require_sri_for "script", "style"
    assert_match %r{require-sri-for script style}, @policy.build

    @policy.require_sri_for
    assert_no_match %r{require-sri-for}, @policy.build

    @policy.require_trusted_types_for :script
    assert_match %r{require-trusted-types-for 'script'}, @policy.build

    @policy.require_trusted_types_for
    assert_no_match %r{require-trusted-types-for}, @policy.build

    @policy.trusted_types :none
    assert_match %r{trusted-types 'none'}, @policy.build

    @policy.trusted_types "foo", "bar"
    assert_match %r{trusted-types foo bar}, @policy.build

    @policy.trusted_types "foo", "bar", :allow_duplicates
    assert_match %r{trusted-types foo bar 'allow-duplicates'}, @policy.build

    @policy.trusted_types
    assert_no_match %r{trusted-types}, @policy.build

    @policy.upgrade_insecure_requests
    assert_match %r{upgrade-insecure-requests}, @policy.build

    @policy.upgrade_insecure_requests false
    assert_no_match %r{upgrade-insecure-requests}, @policy.build
  end

  def test_multiple_sources
    @policy.script_src :self, :https
    assert_equal "script-src 'self' https:", @policy.build
  end

  def test_multiple_directives
    @policy.script_src :self, :https
    @policy.style_src :self, :https
    assert_equal "script-src 'self' https:; style-src 'self' https:", @policy.build
  end

  def test_dynamic_directives
    request = ActionDispatch::Request.new("HTTP_HOST" => "www.example.com")
    controller = Struct.new(:request).new(request)

    @policy.script_src -> { request.host }
    assert_equal "script-src www.example.com", @policy.build(controller)
  end

  def test_mixed_static_and_dynamic_directives
    @policy.script_src :self, -> { "foo.com" }, "bar.com"
    request = ActionDispatch::Request.new({})
    controller = Struct.new(:request).new(request)
    assert_equal "script-src 'self' foo.com bar.com", @policy.build(controller)
  end

  def test_invalid_directive_source
    exception = assert_raises(ArgumentError) do
      @policy.script_src [:self]
    end

    assert_equal "Invalid content security policy source: [:self]", exception.message
  end

  def test_missing_context_for_dynamic_source
    @policy.script_src -> { request.host }

    exception = assert_raises(RuntimeError) do
      @policy.build
    end

    assert_match %r{\AMissing context for the dynamic content security policy source:}, exception.message
  end

  def test_raises_runtime_error_when_unexpected_source
    @policy.plugin_types [:flash]

    exception = assert_raises(RuntimeError) do
      @policy.build
    end

    assert_match %r{\AUnexpected content security policy source:}, exception.message
  end
end

class DefaultContentSecurityPolicyIntegrationTest < ActionDispatch::IntegrationTest
  class PolicyController < ActionController::Base
    def index
      head :ok
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "default_content_security_policy_integration_test" do
      get "/", to: "policy#index"
      get "/redirect", to: redirect("/")
    end
  end

  POLICY = ActionDispatch::ContentSecurityPolicy.new do |p|
    p.default_src -> { :self  }
    p.script_src  -> { :https }
  end

  class PolicyConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.content_security_policy"] = POLICY
      env["action_dispatch.content_security_policy_nonce_generator"] = proc { "iyhD0Yc0W+c=" }
      env["action_dispatch.content_security_policy_report_only"] = false
      env["action_dispatch.show_exceptions"] = false

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use PolicyConfigMiddleware
    middleware.use ActionDispatch::ContentSecurityPolicy::Middleware
  end

  def app
    APP
  end

  def test_adds_nonce_to_script_src_content_security_policy_only_once
    get "/"
    get "/"
    assert_response :success
    assert_policy "default-src 'self'; script-src https: 'nonce-iyhD0Yc0W+c='"
  end

  def test_redirect_works_with_dynamic_sources
    get "/redirect"
    assert_response :redirect
    assert_policy "default-src 'self'; script-src https: 'nonce-iyhD0Yc0W+c='"
  end

  private
    def assert_policy(expected, report_only: false)
      if report_only
        expected_header = "Content-Security-Policy-Report-Only"
        unexpected_header = "Content-Security-Policy"
      else
        expected_header = "Content-Security-Policy"
        unexpected_header = "Content-Security-Policy-Report-Only"
      end

      assert_nil response.headers[unexpected_header]
      assert_equal expected, response.headers[expected_header]
    end
end

class ContentSecurityPolicyIntegrationTest < ActionDispatch::IntegrationTest
  class PolicyController < ActionController::Base
    content_security_policy only: :inline do |p|
      p.default_src "https://example.com"
    end

    content_security_policy only: :conditional, if: :condition? do |p|
      p.default_src "https://true.example.com"
    end

    content_security_policy only: :conditional, unless: :condition? do |p|
      p.default_src "https://false.example.com"
    end

    content_security_policy only: :report_only do |p|
      p.report_uri "/violations"
    end

    content_security_policy only: :script_src do |p|
      p.default_src false
      p.script_src :self
    end

    content_security_policy only: :style_src do |p|
      p.default_src false
      p.style_src :self
    end

    content_security_policy(false, only: :no_policy)

    content_security_policy_report_only only: :report_only

    def index
      head :ok
    end

    def inline
      head :ok
    end

    def conditional
      head :ok
    end

    def report_only
      head :ok
    end

    def script_src
      head :ok
    end

    def style_src
      head :ok
    end

    def no_policy
      head :ok
    end

    private
      def condition?
        params[:condition] == "true"
      end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "content_security_policy_integration_test" do
      get "/", to: "policy#index"
      get "/inline", to: "policy#inline"
      get "/conditional", to: "policy#conditional"
      get "/report-only", to: "policy#report_only"
      get "/script-src", to: "policy#script_src"
      get "/style-src", to: "policy#style_src"
      get "/no-policy", to: "policy#no_policy"
    end
  end

  POLICY = ActionDispatch::ContentSecurityPolicy.new do |p|
    p.default_src :self
  end

  class PolicyConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.content_security_policy"] = POLICY
      env["action_dispatch.content_security_policy_nonce_generator"] = proc { "iyhD0Yc0W+c=" }
      env["action_dispatch.content_security_policy_report_only"] = false
      env["action_dispatch.show_exceptions"] = false

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use PolicyConfigMiddleware
    middleware.use ActionDispatch::ContentSecurityPolicy::Middleware
  end

  def app
    APP
  end

  def test_generates_content_security_policy_header
    get "/"
    assert_policy "default-src 'self'"
  end

  def test_generates_inline_content_security_policy
    get "/inline"
    assert_policy "default-src https://example.com"
  end

  def test_generates_conditional_content_security_policy
    get "/conditional", params: { condition: "true" }
    assert_policy "default-src https://true.example.com"

    get "/conditional", params: { condition: "false" }
    assert_policy "default-src https://false.example.com"
  end

  def test_generates_report_only_content_security_policy
    get "/report-only"
    assert_policy "default-src 'self'; report-uri /violations", report_only: true
  end

  def test_adds_nonce_to_script_src_content_security_policy
    get "/script-src"
    assert_policy "script-src 'self' 'nonce-iyhD0Yc0W+c='"
  end

  def test_adds_nonce_to_style_src_content_security_policy
    get "/style-src"
    assert_policy "style-src 'self' 'nonce-iyhD0Yc0W+c='"
  end

  def test_generates_no_content_security_policy
    get "/no-policy"

    assert_nil response.headers["Content-Security-Policy"]
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
  end

  private
    def assert_policy(expected, report_only: false)
      assert_response :success

      if report_only
        expected_header = "Content-Security-Policy-Report-Only"
        unexpected_header = "Content-Security-Policy"
      else
        expected_header = "Content-Security-Policy"
        unexpected_header = "Content-Security-Policy-Report-Only"
      end

      assert_nil response.headers[unexpected_header]
      assert_equal expected, response.headers[expected_header]
    end
end

class DisabledContentSecurityPolicyIntegrationTest < ActionDispatch::IntegrationTest
  class PolicyController < ActionController::Base
    content_security_policy only: :inline do |p|
      p.default_src "https://example.com"
    end

    def index
      head :ok
    end

    def inline
      head :ok
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "disabled_content_security_policy_integration_test" do
      get "/", to: "policy#index"
      get "/inline", to: "policy#inline"
    end
  end

  class PolicyConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.content_security_policy"] = nil
      env["action_dispatch.content_security_policy_nonce_generator"] = nil
      env["action_dispatch.content_security_policy_report_only"] = false
      env["action_dispatch.show_exceptions"] = false

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use PolicyConfigMiddleware
    middleware.use ActionDispatch::ContentSecurityPolicy::Middleware
  end

  def app
    APP
  end

  def test_generates_no_content_security_policy_by_default
    get "/"
    assert_nil response.headers["Content-Security-Policy"]
  end

  def test_generates_content_security_policy_header_when_globally_disabled
    get "/inline"
    assert_equal "default-src https://example.com", response.headers["Content-Security-Policy"]
  end
end

class NonceDirectiveContentSecurityPolicyIntegrationTest < ActionDispatch::IntegrationTest
  class PolicyController < ActionController::Base
    def index
      head :ok
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "nonce_directive_content_security_policy_integration_test" do
      get "/", to: "policy#index"
    end
  end

  POLICY = ActionDispatch::ContentSecurityPolicy.new do |p|
    p.default_src -> { :self  }
    p.script_src -> { :https }
    p.style_src -> { :https }
  end

  class PolicyConfigMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.content_security_policy"] = POLICY
      env["action_dispatch.content_security_policy_nonce_generator"] = proc { "iyhD0Yc0W+c=" }
      env["action_dispatch.content_security_policy_report_only"] = false
      env["action_dispatch.content_security_policy_nonce_directives"] = %w(script-src)
      env["action_dispatch.show_exceptions"] = false

      @app.call(env)
    end
  end

  APP = build_app(ROUTES) do |middleware|
    middleware.use PolicyConfigMiddleware
    middleware.use ActionDispatch::ContentSecurityPolicy::Middleware
  end

  def app
    APP
  end

  def test_generate_nonce_only_specified_in_nonce_directives
    get "/"

    assert_response :success
    assert_match "script-src https: 'nonce-iyhD0Yc0W+c='", response.headers["Content-Security-Policy"]
    assert_no_match "style-src https: 'nonce-iyhD0Yc0W+c='", response.headers["Content-Security-Policy"]
  end
end
