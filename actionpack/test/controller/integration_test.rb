# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_controllers"
require "rails/engine"

class SessionTest < ActiveSupport::TestCase
  StubApp = lambda { |env|
    [200, { "Content-Type" => "text/html", "Content-Length" => "13" }, ["Hello, World!"]]
  }

  def setup
    @session = ActionDispatch::Integration::Session.new(StubApp)
  end

  def test_https_bang_works_and_sets_truth_by_default
    assert_not_predicate @session, :https?
    @session.https!
    assert_predicate @session, :https?
    @session.https! false
    assert_not_predicate @session, :https?
  end

  def test_host!
    assert_not_equal "glu.ttono.us", @session.host
    @session.host! "rubyonrails.com"
    assert_equal "rubyonrails.com", @session.host
  end

  def test_follow_redirect_raises_when_no_redirect
    @session.stub :redirect?, false do
      assert_raise(RuntimeError) { @session.follow_redirect! }
    end
  end

  def test_get
    path = "/index"; params = "blah"; headers = { location: "blah" }

    assert_called_with @session, :process, [:get, path, params: params, headers: headers] do
      @session.get(path, params: params, headers: headers)
    end
  end

  def test_get_with_env_and_headers
    path = "/index"; params = "blah"; headers = { location: "blah" }; env = { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }
    assert_called_with @session, :process, [:get, path, params: params, headers: headers, env: env] do
      @session.get(path, params: params, headers: headers, env: env)
    end
  end

  def test_post
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:post, path, params: params, headers: headers] do
      @session.post(path, params: params, headers: headers)
    end
  end

  def test_patch
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:patch, path, params: params, headers: headers] do
      @session.patch(path, params: params, headers: headers)
    end
  end

  def test_put
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:put, path, params: params, headers: headers] do
      @session.put(path, params: params, headers: headers)
    end
  end

  def test_delete
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:delete, path, params: params, headers: headers] do
      @session.delete(path, params: params, headers: headers)
    end
  end

  def test_head
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:head, path, params: params, headers: headers] do
      @session.head(path, params: params, headers: headers)
    end
  end

  def test_xml_http_request_get
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:get, path, params: params, headers: headers, xhr: true] do
      @session.get(path, params: params, headers: headers, xhr: true)
    end
  end

  def test_xml_http_request_post
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:post, path, params: params, headers: headers, xhr: true] do
      @session.post(path, params: params, headers: headers, xhr: true)
    end
  end

  def test_xml_http_request_patch
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:patch, path, params: params, headers: headers, xhr: true] do
      @session.patch(path, params: params, headers: headers, xhr: true)
    end
  end

  def test_xml_http_request_put
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:put, path, params: params, headers: headers, xhr: true] do
      @session.put(path, params: params, headers: headers, xhr: true)
    end
  end

  def test_xml_http_request_delete
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:delete, path, params: params, headers: headers, xhr: true] do
      @session.delete(path, params: params, headers: headers, xhr: true)
    end
  end

  def test_xml_http_request_head
    path = "/index"; params = "blah"; headers = { location: "blah" }
    assert_called_with @session, :process, [:head, path, params: params, headers: headers, xhr: true] do
      @session.head(path, params: params, headers: headers, xhr: true)
    end
  end
end

class IntegrationTestTest < ActiveSupport::TestCase
  def setup
    @test = ::ActionDispatch::IntegrationTest.new(:app)
  end

  def test_opens_new_session
    session1 = @test.open_session { |sess| }
    session2 = @test.open_session # implicit session

    assert_not session1.equal?(session2)
  end

  def test_child_session_assertions_bubble_up_to_root
    assertions_before = @test.assertions
    @test.open_session.assert(true)
    assertions_after = @test.assertions

    assert_equal 1, assertions_after - assertions_before
  end

  # RSpec mixes Matchers (which has a #method_missing) into
  # IntegrationTest's superclass.  Make sure IntegrationTest does not
  # try to delegate these methods to the session object.
  def test_does_not_prevent_method_missing_passing_up_to_ancestors
    mixin = Module.new do
      def method_missing(name, *args)
        name.to_s == "foo" ? "pass" : super
      end
    end
    @test.class.superclass.include(mixin)
    begin
      assert_equal "pass", @test.foo
    ensure
      # leave other tests as unaffected as possible
      mixin.remove_method :method_missing
    end
  end
end

# Tests that integration tests don't call Controller test methods for processing.
# Integration tests have their own setup and teardown.
class IntegrationTestUsesCorrectClass < ActionDispatch::IntegrationTest
  def test_integration_methods_called
    reset!
    headers = { "Origin" => "*" }

    %w( get post head patch put delete options ).each do |verb|
      assert_nothing_raised { __send__(verb, "/", headers: headers) }
    end
  end
end

class IntegrationProcessTest < ActionDispatch::IntegrationTest
  class IntegrationController < ActionController::Base
    def get
      respond_to do |format|
        format.html { render plain: "OK", status: 200 }
        format.js { render plain: "JS OK", status: 200 }
        format.json { render json: "JSON OK", status: 200 }
        format.xml { render xml: "<root></root>", status: 200 }
        format.rss { render xml: "<root></root>", status: 200 }
        format.atom { render xml: "<root></root>", status: 200 }
      end
    end

    def get_with_vary_set_x_requested_with
      respond_to do |format|
        format.json do
          response.headers["Vary"] = "X-Requested-With"
          render json: "JSON OK", status: 200
        end
      end
    end

    def get_with_params
      render plain: "foo: #{params[:foo]}", status: 200
    end

    def post
      render plain: "Created", status: 201
    end

    def method
      render plain: "method: #{request.method.downcase}"
    end

    def cookie_monster
      cookies["cookie_1"] = nil
      cookies["cookie_3"] = "chocolate"
      render plain: "Gone", status: 410
    end

    def set_cookie
      cookies["foo"] = "bar"
      head :ok
    end

    def get_cookie
      render plain: cookies["foo"]
    end

    def redirect
      redirect_to action_url("get")
    end

    def redirect_307
      redirect_to action_url("post"), status: 307
    end

    def redirect_308
      redirect_to action_url("post"), status: 308
    end

    def remove_header
      response.headers.delete params[:header]
      head :ok, "c" => "3"
    end
  end

  def test_get
    with_test_route_set do
      get "/get"
      assert_equal 200, status
      assert_equal "OK", status_message
      assert_response 200
      assert_response :success
      assert_response :ok
      assert_equal({}, cookies.to_hash)
      assert_equal "OK", body
      assert_equal "OK", response.body
      assert_kind_of Nokogiri::HTML::Document, html_document
      assert_equal 1, request_count
    end
  end

  def test_get_xml_rss_atom
    %w[ application/xml application/rss+xml application/atom+xml ].each do |mime_string|
      with_test_route_set do
        get "/get", headers: { "HTTP_ACCEPT" => mime_string }
        assert_equal 200, status
        assert_equal "OK", status_message
        assert_response 200
        assert_response :success
        assert_response :ok
        assert_equal({}, cookies.to_hash)
        assert_equal "<root></root>", body
        assert_equal "<root></root>", response.body
        assert_instance_of Nokogiri::XML::Document, html_document
        assert_equal 1, request_count
      end
    end
  end

  def test_post
    with_test_route_set do
      post "/post"
      assert_equal 201, status
      assert_equal "Created", status_message
      assert_response 201
      assert_response :success
      assert_response :created
      assert_equal({}, cookies.to_hash)
      assert_equal "Created", body
      assert_equal "Created", response.body
      assert_kind_of Nokogiri::HTML::Document, html_document
      assert_equal 1, request_count
    end
  end

  test "response cookies are added to the cookie jar for the next request" do
    with_test_route_set do
      cookies["cookie_1"] = "sugar"
      cookies["cookie_2"] = "oatmeal"
      get "/cookie_monster"
      assert_equal "cookie_1=; path=/\ncookie_3=chocolate; path=/", headers["Set-Cookie"]
      assert_equal({ "cookie_1" => "", "cookie_2" => "oatmeal", "cookie_3" => "chocolate" }, cookies.to_hash)
    end
  end

  test "cookie persist to next request" do
    with_test_route_set do
      get "/set_cookie"
      assert_response :success

      assert_equal "foo=bar; path=/", headers["Set-Cookie"]
      assert_equal({ "foo" => "bar" }, cookies.to_hash)

      get "/get_cookie"
      assert_response :success
      assert_equal "bar", body

      assert_nil headers["Set-Cookie"]
      assert_equal({ "foo" => "bar" }, cookies.to_hash)
    end
  end

  test "cookie persist to next request on another domain" do
    with_test_route_set do
      host! "37s.backpack.test"

      get "/set_cookie"
      assert_response :success

      assert_equal "foo=bar; path=/", headers["Set-Cookie"]
      assert_equal({ "foo" => "bar" }, cookies.to_hash)

      get "/get_cookie"
      assert_response :success
      assert_equal "bar", body

      assert_nil headers["Set-Cookie"]
      assert_equal({ "foo" => "bar" }, cookies.to_hash)
    end
  end

  def test_redirect
    with_test_route_set do
      get "/redirect"
      assert_equal 302, status
      assert_equal "Found", status_message
      assert_response 302
      assert_response :redirect
      assert_response :found
      assert_equal "<html><body>You are being <a href=\"http://www.example.com/get\">redirected</a>.</body></html>", response.body
      assert_kind_of Nokogiri::HTML::Document, html_document
      assert_equal 1, request_count

      follow_redirect!
      assert_response :success
      assert_equal "/get", path

      get "/moved"
      assert_response :redirect
      assert_redirected_to "/method"
    end
  end

  def test_307_redirect_uses_the_same_http_verb
    with_test_route_set do
      post "/redirect_307"
      assert_equal 307, status
      follow_redirect!
      assert_equal "POST", request.method
    end
  end

  def test_308_redirect_uses_the_same_http_verb
    with_test_route_set do
      post "/redirect_308"
      assert_equal 308, status
      follow_redirect!
      assert_equal "POST", request.method
    end
  end

  def test_redirect_reset_html_document
    with_test_route_set do
      get "/redirect"
      previous_html_document = html_document

      follow_redirect!

      assert_response :ok
      assert_not_same previous_html_document, html_document
    end
  end

  def test_redirect_with_arguments
    with_test_route_set do
      get "/redirect"
      follow_redirect! params: { foo: :bar }

      assert_response :ok
      assert_equal "bar", request.parameters["foo"]
    end
  end

  def test_xml_http_request_get
    with_test_route_set do
      get "/get", xhr: true
      assert_equal 200, status
      assert_equal "OK", status_message
      assert_response 200
      assert_response :success
      assert_response :ok
      assert_equal "JS OK", response.body
    end
  end

  def test_request_with_bad_format
    with_test_route_set do
      get "/get.php", xhr: true
      assert_equal 406, status
      assert_response 406
      assert_response :not_acceptable
    end
  end

  test "creation of multiple integration sessions" do
    integration_session # initialize first session
    a = open_session
    b = open_session

    assert_not_same(a.integration_session, b.integration_session)
  end

  def test_get_with_query_string
    with_test_route_set do
      get "/get_with_params?foo=bar"
      assert_equal "/get_with_params?foo=bar", request.env["REQUEST_URI"]
      assert_equal "/get_with_params?foo=bar", request.fullpath
      assert_equal "foo=bar", request.env["QUERY_STRING"]
      assert_equal "foo=bar", request.query_string
      assert_equal "bar", request.parameters["foo"]

      assert_equal 200, status
      assert_equal "foo: bar", response.body
    end
  end

  def test_get_with_parameters
    with_test_route_set do
      get "/get_with_params", params: { foo: "bar" }
      assert_equal "/get_with_params", request.env["PATH_INFO"]
      assert_equal "/get_with_params", request.path_info
      assert_equal "foo=bar", request.env["QUERY_STRING"]
      assert_equal "foo=bar", request.query_string
      assert_equal "bar", request.parameters["foo"]

      assert_equal 200, status
      assert_equal "foo: bar", response.body
    end
  end

  def test_post_then_get_with_parameters_do_not_leak_across_requests
    with_test_route_set do
      post "/post", params: { leaks: "does-leak?" }

      get "/get_with_params", params: { foo: "bar" }

      assert_empty request.env["rack.input"].string
      assert_equal "foo=bar", request.env["QUERY_STRING"]
      assert_equal "foo=bar", request.query_string
      assert_equal "bar", request.parameters["foo"]
      assert_predicate request.parameters["leaks"], :nil?
    end
  end

  def test_head
    with_test_route_set do
      head "/get"
      assert_equal 200, status
      assert_equal "", body

      head "/post"
      assert_equal 201, status
      assert_equal "", body

      get "/get/method"
      assert_equal 200, status
      assert_equal "method: get", body

      head "/get/method"
      assert_equal 200, status
      assert_equal "", body
    end
  end

  def test_generate_url_with_controller
    assert_equal "http://www.example.com/foo", url_for(controller: "foo")
  end

  def test_port_via_host!
    with_test_route_set do
      host! "www.example.com:8080"
      get "/get"
      assert_equal 8080, request.port
    end
  end

  def test_port_via_process
    with_test_route_set do
      get "http://www.example.com:8080/get"
      assert_equal 8080, request.port
    end
  end

  def test_https_and_port_via_host_and_https!
    with_test_route_set do
      host! "www.example.com"
      https! true

      get "/get"
      assert_equal 443, request.port
      assert_equal true, request.ssl?

      host! "www.example.com:443"
      https! true

      get "/get"
      assert_equal 443, request.port
      assert_equal true, request.ssl?

      host! "www.example.com:8443"
      https! true

      get "/get"
      assert_equal 8443, request.port
      assert_equal true, request.ssl?
    end
  end

  def test_https_and_port_via_process
    with_test_route_set do
      get "https://www.example.com/get"
      assert_equal 443, request.port
      assert_equal true, request.ssl?

      get "https://www.example.com:8443/get"
      assert_equal 8443, request.port
      assert_equal true, request.ssl?
    end
  end

  def test_respect_removal_of_default_headers_by_a_controller_action
    with_test_route_set do
      with_default_headers "a" => "1", "b" => "2" do
        get "/remove_header", params: { header: "a" }
      end
    end

    assert_not_includes @response.headers, "a", "Response should not include default header removed by the controller action"
    assert_includes @response.headers, "b"
    assert_includes @response.headers, "c"
  end

  def test_accept_not_overridden_when_xhr_true
    with_test_route_set do
      get "/get", headers: { "Accept" => "application/json" }, xhr: true
      assert_equal "application/json", request.accept
      assert_equal "application/json", response.media_type

      get "/get", headers: { "HTTP_ACCEPT" => "application/json" }, xhr: true
      assert_equal "application/json", request.accept
      assert_equal "application/json", response.media_type
    end
  end

  def test_setting_vary_header_when_request_is_xhr_with_accept_header
    with_test_route_set do
      get "/get", headers: { "Accept" => "application/json" }, xhr: true
      assert_equal "Accept", response.headers["Vary"]
    end
  end

  def test_not_setting_vary_header_when_format_is_provided
    with_test_route_set do
      get "/get", params: { format: "json" }
      assert_nil response.headers["Vary"]
    end
  end

  def test_not_setting_vary_header_when_it_has_already_been_set
    with_test_route_set do
      get "/get_with_vary_set_x_requested_with", headers: { "Accept" => "application/json" }, xhr: true
      assert_equal "X-Requested-With", response.headers["Vary"]
    end
  end

  def test_not_setting_vary_header_when_ignore_accept_header_is_set
    original_ignore_accept_header = ActionDispatch::Request.ignore_accept_header
    ActionDispatch::Request.ignore_accept_header = true

    with_test_route_set do
      get "/get", headers: { "Accept" => "application/json" }, xhr: true
      assert_nil response.headers["Vary"]
    end
  ensure
    ActionDispatch::Request.ignore_accept_header = original_ignore_accept_header
  end

  private
    def with_default_headers(headers)
      original = ActionDispatch::Response.default_headers
      ActionDispatch::Response.default_headers = headers
      yield
    ensure
      ActionDispatch::Response.default_headers = original
    end

    def with_test_route_set
      with_routing do |set|
        controller = ::IntegrationProcessTest::IntegrationController.clone
        controller.class_eval do
          include set.url_helpers
        end

        set.draw do
          get "moved" => redirect("/method")

          ActiveSupport::Deprecation.silence do
            match ":action", to: controller, via: [:get, :post], as: :action
            get "get/:action", to: controller, as: :get_action
          end
        end

        singleton_class.include(set.url_helpers)

        yield
      end
    end
end

class MetalIntegrationTest < ActionDispatch::IntegrationTest
  include SharedTestRoutes.url_helpers

  class Poller
    def self.call(env)
      if /^\/success/.match?(env["PATH_INFO"])
        [200, { "Content-Type" => "text/plain", "Content-Length" => "12" }, ["Hello World!"]]
      else
        [404, { "Content-Type" => "text/plain", "Content-Length" => "0" }, []]
      end
    end
  end

  def setup
    @app = Poller
  end

  def test_successful_get
    get "/success"
    assert_response 200
    assert_response :success
    assert_response :ok
    assert_equal "Hello World!", response.body
  end

  def test_failed_get
    get "/failure"
    assert_response 404
    assert_response :not_found
    assert_equal "", response.body
  end

  def test_generate_url_without_controller
    assert_equal "http://www.example.com/foo", url_for(controller: "foo")
  end

  def test_pass_headers
    get "/success", headers: { "Referer" => "http://www.example.com/foo", "Host" => "http://nohost.com" }

    assert_equal "http://nohost.com", @request.env["HTTP_HOST"]
    assert_equal "http://www.example.com/foo", @request.env["HTTP_REFERER"]
  end

  def test_pass_headers_and_env
    get "/success", headers: { "X-Test-Header" => "value" }, env: { "HTTP_REFERER" => "http://test.com/", "HTTP_HOST" => "http://test.com" }

    assert_equal "http://test.com", @request.env["HTTP_HOST"]
    assert_equal "http://test.com/", @request.env["HTTP_REFERER"]
    assert_equal "value", @request.env["HTTP_X_TEST_HEADER"]
  end

  def test_pass_env
    get "/success", env: { "HTTP_REFERER" => "http://test.com/", "HTTP_HOST" => "http://test.com" }

    assert_equal "http://test.com", @request.env["HTTP_HOST"]
    assert_equal "http://test.com/", @request.env["HTTP_REFERER"]
  end

  def test_ignores_common_ports_in_host
    get "http://test.com"
    assert_equal "test.com", @request.env["HTTP_HOST"]

    get "https://test.com"
    assert_equal "test.com", @request.env["HTTP_HOST"]
  end

  def test_keeps_uncommon_ports_in_host
    get "http://test.com:123"
    assert_equal "test.com:123", @request.env["HTTP_HOST"]

    get "http://test.com:443"
    assert_equal "test.com:443", @request.env["HTTP_HOST"]

    get "https://test.com:80"
    assert_equal "test.com:80", @request.env["HTTP_HOST"]
  end
end

class ApplicationIntegrationTest < ActionDispatch::IntegrationTest
  class MetalController < ActionController::Metal
    def new
      self.status = 200
    end
  end

  class TestController < ActionController::Base
    def index
      render plain: "index"
    end
  end

  def self.call(env)
    routes.call(env)
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  class MountedApp < Rails::Engine
    def self.routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end

    routes.draw do
      get "baz", to: "application_integration_test/test#index", as: :baz
    end

    def self.call(*)
    end
  end

  routes.draw do
    get "",    to: "application_integration_test/test#index", as: :empty_string

    get "metal", to: "application_integration_test/metal#new", as: :new_metal

    get "foo", to: "application_integration_test/test#index", as: :foo
    get "bar", to: "application_integration_test/test#index", as: :bar

    mount MountedApp => "/mounted", :as => "mounted"
    get "fooz" => proc { |env| [ 200, { "X-Cascade" => "pass" }, [ "omg" ] ] }, :anchor => false
    get "fooz", to: "application_integration_test/test#index"
  end

  def app
    self.class
  end

  test "includes route helpers" do
    assert_equal "/", empty_string_path
    assert_equal "/foo", foo_path
    assert_equal "/bar", bar_path
  end

  test "includes mounted helpers" do
    assert_equal "/mounted/baz", mounted.baz_path
  end

  test "path after cascade pass" do
    get "/fooz"
    assert_equal "index", response.body
    assert_equal "/fooz", path
  end

  test "route helpers after controller access" do
    get "/"
    assert_equal "/", empty_string_path

    get "/foo"
    assert_equal "/foo", foo_path

    get "/bar"
    assert_equal "/bar", bar_path
  end

  test "route helpers after metal controller access" do
    get "/metal"
    assert_equal "/foo?q=solution", foo_path(q: "solution")
  end

  test "missing route helper before controller access" do
    assert_raise(NameError) { missing_path }
  end

  test "missing route helper after controller access" do
    get "/foo"
    assert_raise(NameError) { missing_path }
  end

  test "process do not modify the env passed as argument" do
    env = { :SERVER_NAME => "server", "action_dispatch.custom" => "custom" }
    old_env = env.dup
    get "/foo", env: env
    assert_equal old_env, env
  end
end

class EnvironmentFilterIntegrationTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def post
      render plain: "Created", status: 201
    end
  end

  def self.call(env)
    env["action_dispatch.parameter_filter"] = [:password]
    routes.call(env)
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  routes.draw do
    match "/post", to: "environment_filter_integration_test/test#post", via: :post
  end

  def app
    self.class
  end

  test "filters rack request form vars" do
    post "/post", params: { username: "cjolly", password: "secret" }

    assert_equal "cjolly", request.filtered_parameters["username"]
    assert_equal "[FILTERED]", request.filtered_parameters["password"]
    assert_equal "[FILTERED]", request.filtered_env["rack.request.form_vars"]
  end
end

class UrlOptionsIntegrationTest < ActionDispatch::IntegrationTest
  class FooController < ActionController::Base
    def index
      render plain: "foo#index"
    end

    def show
      render plain: "foo#show"
    end

    def edit
      render plain: "foo#show"
    end
  end

  class BarController < ActionController::Base
    def default_url_options
      { host: "bar.com" }
    end

    def index
      render plain: "foo#index"
    end
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  def self.call(env)
    routes.call(env)
  end

  def app
    self.class
  end

  routes.draw do
    default_url_options host: "foo.com"

    scope module: "url_options_integration_test" do
      get "/foo" => "foo#index", :as => :foos
      get "/foo/:id" => "foo#show", :as => :foo
      get "/foo/:id/edit" => "foo#edit", :as => :edit_foo
      get "/bar" => "bar#index", :as => :bars
    end
  end

  test "session uses default URL options from routes" do
    assert_equal "http://foo.com/foo", foos_url
  end

  test "current host overrides default URL options from routes" do
    get "/foo"
    assert_response :success
    assert_equal "http://www.example.com/foo", foos_url
  end

  test "controller can override default URL options from request" do
    get "/bar"
    assert_response :success
    assert_equal "http://bar.com/foo", foos_url
  end

  def test_can_override_default_url_options
    original_host = default_url_options.dup

    default_url_options[:host] = "foobar.com"
    assert_equal "http://foobar.com/foo", foos_url

    get "/bar"
    assert_response :success
    assert_equal "http://foobar.com/foo", foos_url
  ensure
    ActionDispatch::Integration::Session.default_url_options = self.default_url_options = original_host
  end

  test "current request path parameters are recalled" do
    get "/foo/1"
    assert_response :success
    assert_equal "/foo/1/edit", url_for(action: "edit", only_path: true)
  end
end

class HeadWithStatusActionIntegrationTest < ActionDispatch::IntegrationTest
  class FooController < ActionController::Base
    def status
      head :ok
    end
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  def self.call(env)
    routes.call(env)
  end

  def app
    self.class
  end

  routes.draw do
    get "/foo/status" => "head_with_status_action_integration_test/foo#status"
  end

  test "get /foo/status with head result does not cause stack overflow error" do
    assert_nothing_raised do
      get "/foo/status"
    end
    assert_response :ok
  end
end

class IntegrationWithRoutingTest < ActionDispatch::IntegrationTest
  class FooController < ActionController::Base
    def index
      render plain: "ok"
    end
  end

  def test_with_routing_resets_session
    klass_namespace = self.class.name.underscore

    with_routing do |routes|
      routes.draw do
        namespace klass_namespace do
          resources :foo, path: "/with"
        end
      end

      get "/integration_with_routing_test/with"
      assert_response 200
      assert_equal "ok", response.body
    end

    with_routing do |routes|
      routes.draw do
        namespace klass_namespace do
          resources :foo, path: "/routing"
        end
      end

      get "/integration_with_routing_test/routing"
      assert_response 200
      assert_equal "ok", response.body
    end
  end
end

# to work in contexts like rspec before(:all)
class IntegrationRequestsWithoutSetup < ActionDispatch::IntegrationTest
  self._setup_callbacks = []
  self._teardown_callbacks = []

  class FooController < ActionController::Base
    def ok
      cookies[:key] = "ok"
      render plain: "ok"
    end
  end

  def test_request
    with_routing do |routes|
      routes.draw do
        ActiveSupport::Deprecation.silence do
          get ":action" => FooController
        end
      end

      get "/ok"

      assert_response 200
      assert_equal "ok", response.body
      assert_equal "ok", cookies["key"]
    end
  end
end

# to ensure that session requirements in setup are persisted in the tests
class IntegrationRequestsWithSessionSetup < ActionDispatch::IntegrationTest
  setup do
    cookies["user_name"] = "david"
  end

  def test_cookies_set_in_setup_are_persisted_through_the_session
    get "/foo"
    assert_equal({ "user_name" => "david" }, cookies.to_hash)
  end
end

class IntegrationRequestEncodersTest < ActionDispatch::IntegrationTest
  class FooController < ActionController::Base
    def foos
      render plain: "ok"
    end

    def foos_json
      render json: params.permit(:foo)
    end

    def foos_wibble
      render plain: "ok"
    end
  end

  def test_standard_json_encoding_works
    with_routing do |routes|
      routes.draw do
        ActiveSupport::Deprecation.silence do
          post ":action" => FooController
        end
      end

      post "/foos_json.json", params: { foo: "fighters" }.to_json,
        headers: { "Content-Type" => "application/json" }

      assert_response :success
      assert_equal({ "foo" => "fighters" }, response.parsed_body)
    end
  end

  def test_encoding_as_json
    post_to_foos as: :json do
      assert_response :success
      assert_equal "application/json", request.media_type
      assert_equal "application/json", request.accepts.first.to_s
      assert_equal :json, request.format.ref
      assert_equal({ "foo" => "fighters" }, request.request_parameters)
      assert_equal({ "foo" => "fighters" }, response.parsed_body)
    end
  end

  def test_doesnt_mangle_request_path
    with_routing do |routes|
      routes.draw do
        ActiveSupport::Deprecation.silence do
          post ":action" => FooController
        end
      end

      post "/foos"
      assert_equal "/foos", request.path

      post "/foos_json", as: :json
      assert_equal "/foos_json", request.path
    end
  end

  def test_encoding_as_without_mime_registration
    assert_raise ArgumentError do
      ActionDispatch::IntegrationTest.register_encoder :wibble
    end
  end

  def test_registering_custom_encoder
    Mime::Type.register "text/wibble", :wibble

    ActionDispatch::IntegrationTest.register_encoder(:wibble,
      param_encoder: -> params { params })

    post_to_foos as: :wibble do
      assert_response :success
      assert_equal "/foos_wibble", request.path
      assert_equal "text/wibble", request.media_type
      assert_equal "text/wibble", request.accepts.first.to_s
      assert_equal :wibble, request.format.ref
      assert_equal Hash.new, request.request_parameters # Unregistered MIME Type can't be parsed.
      assert_equal "ok", response.parsed_body
    end
  ensure
    Mime::Type.unregister :wibble
  end

  def test_parsed_body_without_as_option
    with_routing do |routes|
      routes.draw do
        ActiveSupport::Deprecation.silence do
          get ":action" => FooController
        end
      end

      get "/foos_json.json", params: { foo: "heyo" }

      assert_equal({ "foo" => "heyo" }, response.parsed_body)
    end
  end

  def test_get_parameters_with_as_option
    with_routing do |routes|
      routes.draw do
        ActiveSupport::Deprecation.silence do
          get ":action" => FooController
        end
      end

      get "/foos_json?foo=heyo", as: :json

      assert_equal({ "foo" => "heyo" }, response.parsed_body)
    end
  end

  def test_get_request_with_json_uses_method_override_and_sends_a_post_request
    with_routing do |routes|
      routes.draw do
        ActiveSupport::Deprecation.silence do
          get ":action" => FooController
        end
      end

      get "/foos_json", params: { foo: "heyo" }, as: :json

      assert_equal "POST", request.method
      assert_equal "GET", request.headers["X-Http-Method-Override"]
      assert_equal({ "foo" => "heyo" }, response.parsed_body)
    end
  end

  def test_get_request_with_json_excludes_null_query_string
    with_routing do |routes|
      routes.draw do
        ActiveSupport::Deprecation.silence do
          get ":action" => FooController
        end
      end

      get "/foos_json", as: :json

      assert_equal "http://www.example.com/foos_json", request.url
    end
  end

  private
    def post_to_foos(as:)
      with_routing do |routes|
        routes.draw do
          ActiveSupport::Deprecation.silence do
            post ":action" => FooController
          end
        end

        post "/foos_#{as}", params: { foo: "fighters" }, as: as

        yield
      end
    end
end

class IntegrationFileUploadTest < ActionDispatch::IntegrationTest
  class IntegrationController < ActionController::Base
    def test_file_upload
      render plain: params[:file].size
    end
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  def self.call(env)
    routes.call(env)
  end

  def app
    self.class
  end

  def self.file_fixture_path
    File.expand_path("../fixtures/multipart", __dir__)
  end

  routes.draw do
    post "test_file_upload", to: "integration_file_upload_test/integration#test_file_upload"
  end

  def test_fixture_file_upload
    post "/test_file_upload",
      params: {
        file: fixture_file_upload("/ruby_on_rails.jpg", "image/jpg")
      }
    assert_equal "45142", @response.body
  end
end
