require 'abstract_unit'
require 'controller/fake_controllers'
require 'action_view/vendor/html-scanner'

class SessionTest < ActiveSupport::TestCase
  StubApp = lambda { |env|
    [200, {"Content-Type" => "text/html", "Content-Length" => "13"}, ["Hello, World!"]]
  }

  def setup
    @session = ActionDispatch::Integration::Session.new(StubApp)
  end

  def test_https_bang_works_and_sets_truth_by_default
    assert !@session.https?
    @session.https!
    assert @session.https?
    @session.https! false
    assert !@session.https?
  end

  def test_host!
    assert_not_equal "glu.ttono.us", @session.host
    @session.host! "rubyonrails.com"
    assert_equal "rubyonrails.com", @session.host
  end

  def test_follow_redirect_raises_when_no_redirect
    @session.stubs(:redirect?).returns(false)
    assert_raise(RuntimeError) { @session.follow_redirect! }
  end

  def test_request_via_redirect_uses_given_method
    path = "/somepath"; args = {:id => '1'}; headers = {"X-Test-Header" => "testvalue"}
    @session.expects(:process).with(:put, path, args, headers)
    @session.stubs(:redirect?).returns(false)
    @session.request_via_redirect(:put, path, args, headers)
  end

  def test_request_via_redirect_follows_redirects
    path = "/somepath"; args = {:id => '1'}; headers = {"X-Test-Header" => "testvalue"}
    @session.stubs(:redirect?).returns(true, true, false)
    @session.expects(:follow_redirect!).times(2)
    @session.request_via_redirect(:get, path, args, headers)
  end

  def test_request_via_redirect_returns_status
    path = "/somepath"; args = {:id => '1'}; headers = {"X-Test-Header" => "testvalue"}
    @session.stubs(:redirect?).returns(false)
    @session.stubs(:status).returns(200)
    assert_equal 200, @session.request_via_redirect(:get, path, args, headers)
  end

  def test_get_via_redirect
    path = "/somepath"; args = {:id => '1'}; headers = {"X-Test-Header" => "testvalue" }
    @session.expects(:request_via_redirect).with(:get, path, args, headers)
    @session.get_via_redirect(path, args, headers)
  end

  def test_post_via_redirect
    path = "/somepath"; args = {:id => '1'}; headers = {"X-Test-Header" => "testvalue" }
    @session.expects(:request_via_redirect).with(:post, path, args, headers)
    @session.post_via_redirect(path, args, headers)
  end

  def test_patch_via_redirect
    path = "/somepath"; args = {:id => '1'}; headers = {"X-Test-Header" => "testvalue" }
    @session.expects(:request_via_redirect).with(:patch, path, args, headers)
    @session.patch_via_redirect(path, args, headers)
  end

  def test_put_via_redirect
    path = "/somepath"; args = {:id => '1'}; headers = {"X-Test-Header" => "testvalue" }
    @session.expects(:request_via_redirect).with(:put, path, args, headers)
    @session.put_via_redirect(path, args, headers)
  end

  def test_delete_via_redirect
    path = "/somepath"; args = {:id => '1'}; headers = {"X-Test-Header" => "testvalue" }
    @session.expects(:request_via_redirect).with(:delete, path, args, headers)
    @session.delete_via_redirect(path, args, headers)
  end

  def test_get
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:get,path,params,headers)
    @session.get(path,params,headers)
  end

  def test_post
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:post,path,params,headers)
    @session.post(path,params,headers)
  end

  def test_patch
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:patch,path,params,headers)
    @session.patch(path,params,headers)
  end

  def test_put
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:put,path,params,headers)
    @session.put(path,params,headers)
  end

  def test_delete
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:delete,path,params,headers)
    @session.delete(path,params,headers)
  end

  def test_head
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:head,path,params,headers)
    @session.head(path,params,headers)
  end

  def test_xml_http_request_get
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      "HTTP_ACCEPT"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:get,path,params,headers_after_xhr)
    @session.xml_http_request(:get,path,params,headers)
  end

  def test_xml_http_request_post
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      "HTTP_ACCEPT"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:post,path,params,headers_after_xhr)
    @session.xml_http_request(:post,path,params,headers)
  end

  def test_xml_http_request_patch
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      "HTTP_ACCEPT"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:patch,path,params,headers_after_xhr)
    @session.xml_http_request(:patch,path,params,headers)
  end

  def test_xml_http_request_put
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      "HTTP_ACCEPT"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:put,path,params,headers_after_xhr)
    @session.xml_http_request(:put,path,params,headers)
  end

  def test_xml_http_request_delete
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      "HTTP_ACCEPT"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:delete,path,params,headers_after_xhr)
    @session.xml_http_request(:delete,path,params,headers)
  end

  def test_xml_http_request_head
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      "HTTP_ACCEPT"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:head,path,params,headers_after_xhr)
    @session.xml_http_request(:head,path,params,headers)
  end

  def test_xml_http_request_override_accept
    path = "/index"; params = "blah"; headers = {:location => 'blah', "HTTP_ACCEPT" => "application/xml"}
    headers_after_xhr = headers.merge(
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest"
    )
    @session.expects(:process).with(:post,path,params,headers_after_xhr)
    @session.xml_http_request(:post,path,params,headers)
  end
end

class IntegrationTestTest < ActiveSupport::TestCase
  def setup
    @test = ::ActionDispatch::IntegrationTest.new(:app)
    @test.class.stubs(:fixture_table_names).returns([])
    @session = @test.open_session
  end

  def test_opens_new_session
    session1 = @test.open_session { |sess| }
    session2 = @test.open_session # implicit session

    assert_respond_to session1, :assert_template, "open_session makes assert_template available"
    assert_respond_to session2, :assert_template, "open_session makes assert_template available"
    assert !session1.equal?(session2)
  end

  # RSpec mixes Matchers (which has a #method_missing) into
  # IntegrationTest's superclass.  Make sure IntegrationTest does not
  # try to delegate these methods to the session object.
  def test_does_not_prevent_method_missing_passing_up_to_ancestors
    mixin = Module.new do
      def method_missing(name, *args)
        name.to_s == 'foo' ? 'pass' : super
      end
    end
    @test.class.superclass.__send__(:include, mixin)
    begin
      assert_equal 'pass', @test.foo
    ensure
      # leave other tests as unaffected as possible
      mixin.__send__(:remove_method, :method_missing)
    end
  end
end

# Tests that integration tests don't call Controller test methods for processing.
# Integration tests have their own setup and teardown.
class IntegrationTestUsesCorrectClass < ActionDispatch::IntegrationTest
  def self.fixture_table_names
    []
  end

  def test_integration_methods_called
    reset!
    @integration_session.stubs(:generic_url_rewriter)
    @integration_session.stubs(:process)

    %w( get post head patch put delete ).each do |verb|
      assert_nothing_raised("'#{verb}' should use integration test methods") { __send__(verb, '/') }
    end
  end
end

class IntegrationProcessTest < ActionDispatch::IntegrationTest
  class IntegrationController < ActionController::Base
    def get
      respond_to do |format|
        format.html { render :text => "OK", :status => 200 }
        format.js { render :text => "JS OK", :status => 200 }
      end
    end

    def get_with_params
      render :text => "foo: #{params[:foo]}", :status => 200
    end

    def post
      render :text => "Created", :status => 201
    end

    def method
      render :text => "method: #{request.method.downcase}"
    end

    def cookie_monster
      cookies["cookie_1"] = nil
      cookies["cookie_3"] = "chocolate"
      render :text => "Gone", :status => 410
    end

    def set_cookie
      cookies["foo"] = 'bar'
      head :ok
    end

    def get_cookie
      render :text => cookies["foo"]
    end

    def redirect
      redirect_to action_url('get')
    end

    def remove_header
      response.headers.delete params[:header]
      head :ok, 'c' => '3'
    end
  end

  def test_get
    with_test_route_set do
      get '/get'
      assert_equal 200, status
      assert_equal "OK", status_message
      assert_response 200
      assert_response :success
      assert_response :ok
      assert_equal({}, cookies.to_hash)
      assert_equal "OK", body
      assert_equal "OK", response.body
      assert_kind_of HTML::Document, html_document
      assert_equal 1, request_count
    end
  end

  def test_post
    with_test_route_set do
      post '/post'
      assert_equal 201, status
      assert_equal "Created", status_message
      assert_response 201
      assert_response :success
      assert_response :created
      assert_equal({}, cookies.to_hash)
      assert_equal "Created", body
      assert_equal "Created", response.body
      assert_kind_of HTML::Document, html_document
      assert_equal 1, request_count
    end
  end

  test 'response cookies are added to the cookie jar for the next request' do
    with_test_route_set do
      self.cookies['cookie_1'] = "sugar"
      self.cookies['cookie_2'] = "oatmeal"
      get '/cookie_monster'
      assert_equal "cookie_1=; path=/\ncookie_3=chocolate; path=/", headers["Set-Cookie"]
      assert_equal({"cookie_1"=>"", "cookie_2"=>"oatmeal", "cookie_3"=>"chocolate"}, cookies.to_hash)
    end
  end

  test 'cookie persist to next request' do
    with_test_route_set do
      get '/set_cookie'
      assert_response :success

      assert_equal "foo=bar; path=/", headers["Set-Cookie"]
      assert_equal({"foo"=>"bar"}, cookies.to_hash)

      get '/get_cookie'
      assert_response :success
      assert_equal "bar", body

      assert_equal nil, headers["Set-Cookie"]
      assert_equal({"foo"=>"bar"}, cookies.to_hash)
    end
  end

  test 'cookie persist to next request on another domain' do
    with_test_route_set do
      host! "37s.backpack.test"

      get '/set_cookie'
      assert_response :success

      assert_equal "foo=bar; path=/", headers["Set-Cookie"]
      assert_equal({"foo"=>"bar"}, cookies.to_hash)

      get '/get_cookie'
      assert_response :success
      assert_equal "bar", body

      assert_equal nil, headers["Set-Cookie"]
      assert_equal({"foo"=>"bar"}, cookies.to_hash)
    end
  end

  def test_redirect
    with_test_route_set do
      get '/redirect'
      assert_equal 302, status
      assert_equal "Found", status_message
      assert_response 302
      assert_response :redirect
      assert_response :found
      assert_equal "<html><body>You are being <a href=\"http://www.example.com/get\">redirected</a>.</body></html>", response.body
      assert_kind_of HTML::Document, html_document
      assert_equal 1, request_count

      follow_redirect!
      assert_response :success
      assert_equal "/get", path

      get '/moved'
      assert_response :redirect
      assert_redirected_to '/method'
    end
  end

  def test_xml_http_request_get
    with_test_route_set do
      xhr :get, '/get'
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
      xhr :get, '/get.php'
      assert_equal 406, status
      assert_response 406
      assert_response :not_acceptable
    end
  end

  def test_get_with_query_string
    with_test_route_set do
      get '/get_with_params?foo=bar'
      assert_equal '/get_with_params?foo=bar', request.env["REQUEST_URI"]
      assert_equal '/get_with_params?foo=bar', request.fullpath
      assert_equal "foo=bar", request.env["QUERY_STRING"]
      assert_equal 'foo=bar', request.query_string
      assert_equal 'bar', request.parameters['foo']

      assert_equal 200, status
      assert_equal "foo: bar", response.body
    end
  end

  def test_get_with_parameters
    with_test_route_set do
      get '/get_with_params', :foo => "bar"
      assert_equal '/get_with_params', request.env["PATH_INFO"]
      assert_equal '/get_with_params', request.path_info
      assert_equal 'foo=bar', request.env["QUERY_STRING"]
      assert_equal 'foo=bar', request.query_string
      assert_equal 'bar', request.parameters['foo']

      assert_equal 200, status
      assert_equal "foo: bar", response.body
    end
  end

  def test_head
    with_test_route_set do
      head '/get'
      assert_equal 200, status
      assert_equal "", body

      head '/post'
      assert_equal 201, status
      assert_equal "", body

      get '/get/method'
      assert_equal 200, status
      assert_equal "method: get", body

      head '/get/method'
      assert_equal 200, status
      assert_equal "", body
    end
  end

  def test_generate_url_with_controller
    assert_equal 'http://www.example.com/foo', url_for(:controller => "foo")
  end

  def test_port_via_host!
    with_test_route_set do
      host! 'www.example.com:8080'
      get '/get'
      assert_equal 8080, request.port
    end
  end

  def test_port_via_process
    with_test_route_set do
      get 'http://www.example.com:8080/get'
      assert_equal 8080, request.port
    end
  end

  def test_https_and_port_via_host_and_https!
    with_test_route_set do
      host! 'www.example.com'
      https! true

      get '/get'
      assert_equal 443, request.port
      assert_equal true, request.ssl?

      host! 'www.example.com:443'
      https! true

      get '/get'
      assert_equal 443, request.port
      assert_equal true, request.ssl?

      host! 'www.example.com:8443'
      https! true

      get '/get'
      assert_equal 8443, request.port
      assert_equal true, request.ssl?
    end
  end

  def test_https_and_port_via_process
    with_test_route_set do
      get 'https://www.example.com/get'
      assert_equal 443, request.port
      assert_equal true, request.ssl?

      get 'https://www.example.com:8443/get'
      assert_equal 8443, request.port
      assert_equal true, request.ssl?
    end
  end

  def test_respect_removal_of_default_headers_by_a_controller_action
    with_test_route_set do
      with_default_headers 'a' => '1', 'b' => '2' do
        get '/remove_header', header: 'a'
      end
    end

    assert_not_includes @response.headers, 'a', 'Response should not include default header removed by the controller action'
    assert_includes @response.headers, 'b'
    assert_includes @response.headers, 'c'
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
          get 'moved' => redirect('/method')

          match ':action', :to => controller, :via => [:get, :post], :as => :action
          get 'get/:action', :to => controller, :as => :get_action
        end

        self.singleton_class.send(:include, set.url_helpers)

        yield
      end
    end
end

class MetalIntegrationTest < ActionDispatch::IntegrationTest
  include SharedTestRoutes.url_helpers

  class Poller
    def self.call(env)
      if env["PATH_INFO"] =~ /^\/success/
        [200, {"Content-Type" => "text/plain", "Content-Length" => "12"}, ["Hello World!"]]
      else
        [404, {"Content-Type" => "text/plain", "Content-Length" => "0"}, []]
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
    assert_equal '', response.body
  end

  def test_generate_url_without_controller
    assert_equal 'http://www.example.com/foo', url_for(:controller => "foo")
  end

  def test_pass_headers
    get "/success", {}, "Referer" => "http://www.example.com/foo", "Host" => "http://nohost.com"

    assert_equal "http://nohost.com", @request.env["HTTP_HOST"]
    assert_equal "http://www.example.com/foo", @request.env["HTTP_REFERER"]
  end

  def test_pass_env
    get "/success", {}, "HTTP_REFERER" => "http://test.com/", "HTTP_HOST" => "http://test.com"

    assert_equal "http://test.com", @request.env["HTTP_HOST"]
    assert_equal "http://test.com/", @request.env["HTTP_REFERER"]
  end

end

class ApplicationIntegrationTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def index
      render :text => "index"
    end
  end

  def self.call(env)
    routes.call(env)
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  class MountedApp
    def self.routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end

    routes.draw do
      get 'baz', :to => 'application_integration_test/test#index', :as => :baz
    end

    def self.call(*)
    end
  end

  routes.draw do
    get '',    :to => 'application_integration_test/test#index', :as => :empty_string

    get 'foo', :to => 'application_integration_test/test#index', :as => :foo
    get 'bar', :to => 'application_integration_test/test#index', :as => :bar

    mount MountedApp => '/mounted', :as => "mounted"
    get 'fooz' => proc { |env| [ 200, {'X-Cascade' => 'pass'}, [ "omg" ] ] }, anchor: false
    get 'fooz', :to => 'application_integration_test/test#index'
  end

  def app
    self.class
  end

  test "includes route helpers" do
    assert_equal '/', empty_string_path
    assert_equal '/foo', foo_path
    assert_equal '/bar', bar_path
  end

  test "includes mounted helpers" do
    assert_equal '/mounted/baz', mounted.baz_path
  end

  test "path after cascade pass" do
    get '/fooz'
    assert_equal 'index', response.body
    assert_equal '/fooz', path
  end

  test "route helpers after controller access" do
    get '/'
    assert_equal '/', empty_string_path

    get '/foo'
    assert_equal '/foo', foo_path

    get '/bar'
    assert_equal '/bar', bar_path
  end

  test "missing route helper before controller access" do
    assert_raise(NameError) { missing_path }
  end

  test "missing route helper after controller access" do
    get '/foo'
    assert_raise(NameError) { missing_path }
  end

  test "process do not modify the env passed as argument" do
    env = { :SERVER_NAME => 'server', 'action_dispatch.custom' => 'custom' }
    old_env = env.dup
    get '/foo', nil, env
    assert_equal old_env, env
  end
end

class EnvironmentFilterIntegrationTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def post
      render :text => "Created", :status => 201
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
    match '/post', :to => 'environment_filter_integration_test/test#post', :via => :post
  end

  def app
    self.class
  end

  test "filters rack request form vars" do
    post "/post", :username => 'cjolly', :password => 'secret'

    assert_equal 'cjolly', request.filtered_parameters['username']
    assert_equal '[FILTERED]', request.filtered_parameters['password']
    assert_equal '[FILTERED]', request.filtered_env['rack.request.form_vars']
  end
end

class UrlOptionsIntegrationTest < ActionDispatch::IntegrationTest
  class FooController < ActionController::Base
    def index
      render :text => "foo#index"
    end

    def show
      render :text => "foo#show"
    end

    def edit
      render :text => "foo#show"
    end
  end

  class BarController < ActionController::Base
    def default_url_options
      { :host => "bar.com" }
    end

    def index
      render :text => "foo#index"
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
    default_url_options :host => "foo.com"

    scope :module => "url_options_integration_test" do
      get "/foo" => "foo#index", :as => :foos
      get "/foo/:id" => "foo#show", :as => :foo
      get "/foo/:id/edit" => "foo#edit", :as => :edit_foo
      get "/bar" => "bar#index", :as => :bars
    end
  end

  test "session uses default url options from routes" do
    assert_equal "http://foo.com/foo", foos_url
  end

  test "current host overrides default url options from routes" do
    get "/foo"
    assert_response :success
    assert_equal "http://www.example.com/foo", foos_url
  end

  test "controller can override default url options from request" do
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
    assert_equal "/foo/1/edit", url_for(:action => 'edit', :only_path => true)
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
    get "/foo/status" => 'head_with_status_action_integration_test/foo#status'
  end

  test "get /foo/status with head result does not cause stack overflow error" do
    assert_nothing_raised do
      get '/foo/status'
    end
    assert_response :ok
  end
end
