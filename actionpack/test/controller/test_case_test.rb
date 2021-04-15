# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_controllers"
require "active_support/json/decoding"
require "rails/engine"

class TestCaseTest < ActionController::TestCase
  def self.fixture_path; end
  self.file_fixture_path = File.expand_path("../fixtures/multipart", __dir__)

  class TestController < ActionController::Base
    def no_op
      render plain: "dummy"
    end

    def set_flash
      flash["test"] = ">#{flash["test"]}<"
      render plain: "ignore me"
    end

    def delete_flash
      flash.delete("test")
      render plain: "ignore me"
    end

    def set_flash_now
      flash.now["test_now"] = ">#{flash["test_now"]}<"
      render plain: "ignore me"
    end

    def set_session
      session["string"] = "A wonder"
      session[:symbol] = "it works"
      render plain: "Success"
    end

    def reset_the_session
      reset_session
      render plain: "ignore me"
    end

    def render_raw_post
      raise ActiveSupport::TestCase::Assertion, "#raw_post is blank" if request.raw_post.blank?
      render plain: request.raw_post
    end

    def render_body
      render plain: request.body.read
    end

    def test_params
      render plain: ::JSON.dump(params.to_unsafe_h)
    end

    def test_query_parameters
      render plain: ::JSON.dump(request.query_parameters)
    end

    def test_request_parameters
      render plain: request.request_parameters.inspect
    end

    def test_uri
      render plain: request.fullpath
    end

    def test_format
      render plain: request.format
    end

    def test_query_string
      render plain: request.query_string
    end

    def test_protocol
      render plain: request.protocol
    end

    def test_headers
      render plain: ::JSON.dump(request.headers.env)
    end

    def test_html_output
      render plain: <<HTML
<html>
  <body>
    <a href="/"><img src="/images/button.png" /></a>
    <div id="foo">
      <ul>
        <li class="item">hello</li>
        <li class="item">goodbye</li>
      </ul>
    </div>
    <div id="bar">
      <form action="/somewhere">
        Name: <input type="text" name="person[name]" id="person_name" />
      </form>
    </div>
  </body>
</html>
HTML
    end

    def test_xml_output
      response.content_type = params[:response_as]
      render plain: <<XML
<?xml version="1.0" encoding="UTF-8"?>
<root>
  <area><p>area is an empty tag in HTML, so it won't contain this content</p></area>
</root>
XML
    end

    def test_only_one_param
      render plain: (params[:left] && params[:right]) ? "EEP, Both here!" : "OK"
    end

    def test_remote_addr
      render plain: (request.remote_addr || "not specified")
    end

    def test_file_upload
      render plain: params[:file].size
    end

    def test_send_file
      send_file(__FILE__)
    end

    def redirect_to_same_controller
      redirect_to controller: "test", action: "test_uri", id: 5
    end

    def redirect_to_different_controller
      redirect_to controller: "fail", id: 5
    end

    def create
      head :created, location: "/resource"
    end

    def render_cookie
      render plain: cookies["foo"]
    end

    def delete_cookie
      cookies.delete("foo")
      render plain: "ok"
    end

    def test_without_body
      render html: '<div class="foo"></div>'.html_safe
    end

    def test_with_body
      render html: '<body class="foo"></body>'.html_safe
    end

    def render_json
      render json: request.raw_post
    end

    def boom
      raise "boom!"
    end

    private
      def generate_url(opts)
        url_for(opts.merge(action: "test_uri"))
      end
  end

  def setup
    super
    @controller = TestController.new
    @request.delete_header "PATH_INFO"
    @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
      r.draw do
        ActiveSupport::Deprecation.silence do
          get ":controller(/:action(/:id))"
        end
      end
    end
  end

  class DefaultUrlOptionsCachingController < ActionController::Base
    before_action { @dynamic_opt = "opt" }

    def test_url_options_reset
      render plain: url_for
    end

    def default_url_options
      if defined?(@dynamic_opt)
        super.merge dynamic_opt: @dynamic_opt
      else
        super
      end
    end
  end

  def test_assert_select_without_body
    get :test_without_body

    assert_select "body", 0
    assert_select "div.foo"
  end

  def test_assert_select_with_body
    get :test_with_body

    assert_select "body.foo"
  end

  def test_url_options_reset
    @controller = DefaultUrlOptionsCachingController.new
    get :test_url_options_reset
    assert_nil @request.params["dynamic_opt"]
    assert_match(/dynamic_opt=opt/, @response.body)
  end

  def test_raw_post_handling
    params = Hash[:page, { name: "page name" }, "some key", 123]
    post :render_raw_post, params: params.dup

    assert_equal params.to_query, @response.body
  end

  def test_params_round_trip
    params = { "foo" => { "contents" => [{ "name" => "gorby", "id" => "123" }, { "name" => "puff", "d" => "true" }] } }
    post :test_params, params: params.dup

    controller_info = { "controller" => "test_case_test/test", "action" => "test_params" }
    assert_equal params.merge(controller_info), JSON.parse(@response.body)
  end

  def test_handle_to_params
    klass = Class.new do
      def to_param
        "bar"
      end
    end

    post :test_params, params: { foo: klass.new }

    assert_equal JSON.parse(@response.body)["foo"], "bar"
  end

  def test_body_stream
    params = Hash[:page, { name: "page name" }, "some key", 123]

    post :render_body, params: params.dup

    assert_equal params.to_query, @response.body
  end

  def test_document_body_and_params_with_post
    post :test_params, params: { id: 1 }
    assert_equal({ "id" => "1", "controller" => "test_case_test/test", "action" => "test_params" }, ::JSON.parse(@response.body))
  end

  def test_document_body_with_post
    post :render_body, body: "document body"
    assert_equal "document body", @response.body
  end

  def test_document_body_with_put
    put :render_body, body: "document body"
    assert_equal "document body", @response.body
  end

  def test_head
    head :test_params
    assert_equal 200, @response.status
  end

  def test_process_without_flash
    process :set_flash
    assert_equal "><", flash["test"]
  end

  def test_process_with_flash
    process :set_flash,
      method: "GET",
      flash: { "test" => "value" }
    assert_equal ">value<", flash["test"]
  end

  def test_process_with_flash_now
    process :set_flash_now,
      method: "GET",
      flash: { "test_now" => "value_now" }
    assert_equal ">value_now<", flash["test_now"]
  end

  def test_process_delete_flash
    process :set_flash
    process :delete_flash
    assert_empty flash
    assert_empty session
  end

  def test_process_with_session
    process :set_session
    assert_equal "A wonder", session["string"], "A value stored in the session should be available by string key"
    assert_equal "A wonder", session[:string], "Test session hash should allow indifferent access"
    assert_equal "it works", session["symbol"], "Test session hash should allow indifferent access"
    assert_equal "it works", session[:symbol], "Test session hash should allow indifferent access"
  end

  def test_process_with_session_kwarg
    process :no_op, method: "GET", session: { "string" => "value1", symbol: "value2" }
    assert_equal "value1", session["string"]
    assert_equal "value1", session[:string]
    assert_equal "value2", session["symbol"]
    assert_equal "value2", session[:symbol]
  end

  def test_process_merges_session_arg
    session[:foo] = "bar"
    get :no_op, session: { bar: "baz" }
    assert_equal "bar", session[:foo]
    assert_equal "baz", session[:bar]
  end

  def test_merged_session_arg_is_retained_across_requests
    get :no_op, session: { foo: "bar" }
    assert_equal "bar", session[:foo]
    get :no_op
    assert_equal "bar", session[:foo]
  end

  def test_process_overwrites_existing_session_arg
    session[:foo] = "bar"
    get :no_op, session: { foo: "baz" }
    assert_equal "baz", session[:foo]
  end

  def test_session_is_cleared_from_controller_after_reset_session
    process :set_session
    process :reset_the_session
    assert_equal Hash.new, @controller.session.to_hash
  end

  def test_session_is_cleared_from_request_after_reset_session
    process :set_session
    process :reset_the_session
    assert_equal Hash.new, @request.session.to_hash
  end

  def test_response_and_request_have_nice_accessors
    process :no_op
    assert_equal @response, response
    assert_equal @request, request
  end

  def test_process_with_request_uri_with_no_params
    process :test_uri
    assert_equal "/test_case_test/test/test_uri", @response.body
  end

  def test_process_with_symbol_method
    process :test_uri, method: :get
    assert_equal "/test_case_test/test/test_uri", @response.body
  end

  def test_process_with_request_uri_with_params
    process :test_uri,
      method: "GET",
      params: { id: 7 }

    assert_equal "/test_case_test/test/test_uri/7", @response.body
  end

  def test_process_with_request_uri_with_params_with_explicit_uri
    @request.env["PATH_INFO"] = "/explicit/uri"
    process :test_uri, method: "GET", params: { id: 7 }
    assert_equal "/explicit/uri", @response.body
  end

  def test_process_with_query_string
    process :test_query_string,
      method: "GET",
      params: { q: "test" }
    assert_equal "q=test", @response.body
  end

  def test_process_with_query_string_with_explicit_uri
    @request.env["PATH_INFO"] = "/explicit/uri"
    @request.env["QUERY_STRING"] = "q=test?extra=question"
    process :test_query_string
    assert_equal "q=test?extra=question", @response.body
  end

  def test_multiple_calls
    process :test_only_one_param, method: "GET", params: { left: true }
    assert_equal "OK", @response.body
    process :test_only_one_param, method: "GET", params: { right: true }
    assert_equal "OK", @response.body
  end

  def test_should_impose_childless_html_tags_in_html
    process :test_xml_output, params: { response_as: "text/html" }

    # <area> auto-closes, so the <p> becomes a sibling
    if defined?(JRUBY_VERSION)
      # https://github.com/sparklemotion/nokogiri/issues/1653
      # HTML parser "fixes" "broken" markup in slightly different ways
      assert_select "root > map > area + p"
    else
      assert_select "root > area + p"
    end
  end

  def test_should_not_impose_childless_html_tags_in_xml
    process :test_xml_output, params: { response_as: "application/xml" }

    # <area> is not special, so the <p> is its child
    assert_select "root > area > p"
  end

  def test_assert_generates
    assert_generates "controller/action/5", controller: "controller", action: "action", id: "5"
    assert_generates "controller/action/7", { id: "7" }, { controller: "controller", action: "action" }
    assert_generates "controller/action/5", { controller: "controller", action: "action", id: "5", name: "bob" }, {}, { name: "bob" }
    assert_generates "controller/action/7", { id: "7", name: "bob" }, { controller: "controller", action: "action" }, { name: "bob" }
    assert_generates "controller/action/7", { id: "7" }, { controller: "controller", action: "action", name: "bob" }, {}
  end

  def test_assert_routing
    assert_routing "content", controller: "content", action: "index"
  end

  def test_assert_routing_with_method
    with_routing do |set|
      set.draw { resources(:content) }
      assert_routing({ method: "post", path: "content" }, { controller: "content", action: "create" })
    end
  end

  def test_assert_routing_in_module
    with_routing do |set|
      set.draw do
        namespace :admin do
          get "user" => "user#index"
        end
      end

      assert_routing "admin/user", controller: "admin/user", action: "index"
    end
  end

  def test_assert_routing_with_glob
    with_routing do |set|
      set.draw { get("*path" => "pages#show") }
      assert_routing("/company/about", controller: "pages", action: "show", path: "company/about")
    end
  end

  def test_params_passing
    get :test_params, params: {
      page: {
        name: "Page name",
        month: "4",
        year: "2004",
        day: "6"
      }
    }
    parsed_params = ::JSON.parse(@response.body)
    assert_equal(
      {
        "controller" => "test_case_test/test", "action" => "test_params",
        "page" => { "name" => "Page name", "month" => "4", "year" => "2004", "day" => "6" }
      },
      parsed_params
    )
  end

  def test_nil_params
    get :test_params, params: nil
    parsed_params = JSON.parse(@response.body)
    assert_equal(
      {
        "action" => "test_params",
        "controller" => "test_case_test/test"
      },
      parsed_params
    )
  end

  def test_query_param_named_action
    get :test_query_parameters, params: { action: "foobar" }
    parsed_params = JSON.parse(@response.body)
    assert_equal({ "action" => "foobar" }, parsed_params)
  end

  def test_request_param_named_action
    post :test_request_parameters, params: { action: "foobar" }
    parsed_params = eval(@response.body)
    assert_equal({ "action" => "foobar" }, parsed_params)
  end

  def test_kwarg_params_passing_with_session_and_flash
    get :test_params, params: {
      page: {
        name: "Page name",
        month: "4",
        year: "2004",
        day: "6"
      }
    }, session: { "foo" => "bar" }, flash: { notice: "created" }

    parsed_params = ::JSON.parse(@response.body)
    assert_equal(
      { "controller" => "test_case_test/test", "action" => "test_params",
       "page" => { "name" => "Page name", "month" => "4", "year" => "2004", "day" => "6" } },
      parsed_params
    )

    assert_equal "bar", session[:foo]
    assert_equal "created", flash[:notice]
  end

  def test_params_passing_with_integer
    get :test_params, params: {
      page: { name: "Page name", month: 4, year: 2004, day: 6 }
    }
    parsed_params = ::JSON.parse(@response.body)
    assert_equal(
      { "controller" => "test_case_test/test", "action" => "test_params",
       "page" => { "name" => "Page name", "month" => "4", "year" => "2004", "day" => "6" } },
      parsed_params
    )
  end

  def test_params_passing_with_integers_when_not_html_request
    get :test_params, params: { format: "json", count: 999 }
    parsed_params = ::JSON.parse(@response.body)
    assert_equal(
      { "controller" => "test_case_test/test", "action" => "test_params",
       "format" => "json", "count" => "999" },
      parsed_params
    )
  end

  def test_params_passing_path_parameter_is_string_when_not_html_request
    get :test_params, params: { format: "json", id: 1 }
    parsed_params = ::JSON.parse(@response.body)
    assert_equal(
      { "controller" => "test_case_test/test", "action" => "test_params",
       "format" => "json", "id" => "1" },
      parsed_params
    )
  end

  def test_params_passing_with_frozen_values
    assert_nothing_raised do
      get :test_params, params: {
        frozen: -"icy", frozens: [-"icy"].freeze, deepfreeze: { frozen: -"icy" }.freeze
      }
    end
    parsed_params = ::JSON.parse(@response.body)
    assert_equal(
      { "controller" => "test_case_test/test", "action" => "test_params",
       "frozen" => "icy", "frozens" => ["icy"], "deepfreeze" => { "frozen" => "icy" } },
      parsed_params
    )
  end

  def test_params_passing_doesnt_modify_in_place
    page = { name: "Page name", month: 4, year: 2004, day: 6 }
    get :test_params, params: { page: page }
    assert_equal 2004, page[:year]
  end

  test "set additional HTTP headers" do
    @request.headers["Referer"] = "http://nohost.com/home"
    @request.headers["Content-Type"] = "application/rss+xml"
    get :test_headers
    parsed_env = ActiveSupport::JSON.decode(@response.body)
    assert_equal "http://nohost.com/home", parsed_env["HTTP_REFERER"]
    assert_equal "application/rss+xml", parsed_env["CONTENT_TYPE"]
  end

  test "set additional env variables" do
    @request.headers["HTTP_REFERER"] = "http://example.com/about"
    @request.headers["CONTENT_TYPE"] = "application/json"
    get :test_headers
    parsed_env = ActiveSupport::JSON.decode(@response.body)
    assert_equal "http://example.com/about", parsed_env["HTTP_REFERER"]
    assert_equal "application/json", parsed_env["CONTENT_TYPE"]
  end

  def test_using_as_json_sets_request_content_type_to_json
    post :render_body, params: { bool_value: true, str_value: "string", num_value: 2 }, as: :json

    assert_equal "application/json", @request.headers["CONTENT_TYPE"]
    assert_equal true, @request.request_parameters["bool_value"]
    assert_equal "string", @request.request_parameters["str_value"]
    assert_equal 2, @request.request_parameters["num_value"]
  end

  def test_using_as_json_sets_format_json
    post :render_body, params: { bool_value: true, str_value: "string", num_value: 2 }, as: :json
    assert_equal "json", @request.format
  end

  def test_using_as_json_with_empty_params
    post :test_params, params: { foo: { bar: [] } }, as: :json

    assert_equal({ "bar" => [] }, JSON.load(response.body)["foo"])
  end

  def test_using_as_json_with_path_parameters
    post :test_params, params: { id: "12345" }, as: :json

    assert_equal("12345", @request.path_parameters[:id])
  end

  def test_mutating_content_type_headers_for_plain_text_files_sets_the_header
    @request.headers["Content-Type"] = "text/plain"
    post :render_body, params: { name: "foo.txt" }

    assert_equal "text/plain", @request.headers["Content-type"]
    assert_equal "foo.txt", @request.request_parameters[:name]
    assert_equal "render_body", @request.path_parameters[:action]
  end

  def test_mutating_content_type_headers_for_html_files_sets_the_header
    @request.headers["Content-Type"] = "text/html"
    post :render_body, params: { name: "foo.html" }

    assert_equal "text/html", @request.headers["Content-type"]
    assert_equal "foo.html", @request.request_parameters[:name]
    assert_equal "render_body", @request.path_parameters[:action]
  end

  def test_mutating_content_type_headers_for_non_registered_mime_type_raises_an_error
    assert_raises(RuntimeError) do
      @request.headers["Content-Type"] = "type/fake"
      post :render_body, params: { name: "foo.fake" }
    end
  end

  def test_id_converted_to_string
    get :test_params, params: {
      id: 20, foo: Object.new
    }
    assert_kind_of String, @request.path_parameters[:id]
  end

  def test_array_path_parameter_handled_properly
    with_routing do |set|
      set.draw do
        get "file/*path", to: "test_case_test/test#test_params"

        ActiveSupport::Deprecation.silence do
          get ":controller/:action"
        end
      end

      get :test_params, params: { path: ["hello", "world"] }
      assert_equal ["hello", "world"], @request.path_parameters[:path]
      assert_equal "hello/world", @request.path_parameters[:path].to_param
    end
  end

  def test_assert_realistic_path_parameters
    get :test_params, params: { id: 20, foo: Object.new }

    # All elements of path_parameters should use Symbol keys
    @request.path_parameters.each_key do |key|
      assert_kind_of Symbol, key
    end
  end

  def test_with_routing_places_routes_back
    assert @routes
    routes_id = @routes.object_id

    begin
      with_routing { raise "fail" }
      fail "Should not be here."
    rescue RuntimeError
    end

    assert @routes
    assert_equal routes_id, @routes.object_id
  end

  def test_remote_addr
    get :test_remote_addr
    assert_equal "0.0.0.0", @response.body

    @request.remote_addr = "192.0.0.1"
    get :test_remote_addr
    assert_equal "192.0.0.1", @response.body
  end

  def test_header_properly_reset_after_remote_http_request
    get :test_params, xhr: true
    assert_nil @request.env["HTTP_X_REQUESTED_WITH"]
    assert_nil @request.env["HTTP_ACCEPT"]
  end

  def test_xhr_with_params
    get :test_params, params: { id: 1 }, xhr: true

    assert_equal({ "id" => "1", "controller" => "test_case_test/test", "action" => "test_params" }, ::JSON.parse(@response.body))
  end

  def test_xhr_with_session
    get :set_session, xhr: true

    assert_equal "A wonder", session["string"], "A value stored in the session should be available by string key"
    assert_equal "A wonder", session[:string], "Test session hash should allow indifferent access"
    assert_equal "it works", session["symbol"], "Test session hash should allow indifferent access"
    assert_equal "it works", session[:symbol], "Test session hash should allow indifferent access"
  end

  def test_params_reset_between_post_requests
    post :no_op, params: { foo: "bar" }
    assert_equal "bar", @request.params[:foo]

    post :no_op
    assert_predicate @request.params[:foo], :blank?
  end

  def test_filtered_parameters_reset_between_requests
    get :no_op, params: { foo: "bar" }
    assert_equal "bar", @request.filtered_parameters[:foo]

    get :no_op, params: { foo: "baz" }
    assert_equal "baz", @request.filtered_parameters[:foo]
  end

  def test_raw_post_reset_between_post_requests
    post :no_op, params: { foo: "bar" }
    assert_equal "foo=bar", @request.raw_post

    post :no_op, params: { foo: "baz" }
    assert_equal "foo=baz", @request.raw_post
  end

  def test_content_length_reset_after_post_request
    post :no_op, params: { foo: "bar" }
    assert_not_equal 0, @request.content_length

    get :no_op
    assert_equal 0, @request.content_length
  end

  def test_path_is_kept_after_the_request
    get :test_params, params: { id: "foo" }
    assert_equal "/test_case_test/test/test_params/foo", @request.path
  end

  def test_path_params_reset_between_request
    get :test_params, params: { id: "foo" }
    assert_equal "foo", @request.path_parameters[:id]

    get :test_params
    assert_nil @request.path_parameters[:id]
  end

  def test_request_protocol_is_reset_after_request
    get :test_protocol
    assert_equal "http://", @response.body

    @request.env["HTTPS"] = "on"
    get :test_protocol
    assert_equal "https://", @response.body

    @request.env.delete("HTTPS")
    get :test_protocol
    assert_equal "http://", @response.body
  end

  def test_request_format
    get :test_format, params: { format: "html" }
    assert_equal "text/html", @response.body

    get :test_format, params: { format: "json" }
    assert_equal "application/json", @response.body

    get :test_format, params: { format: "xml" }
    assert_equal "application/xml", @response.body

    get :test_format
    assert_equal "text/html", @response.body
  end

  def test_request_format_kwarg
    get :test_format, format: "html"
    assert_equal "text/html", @response.body

    get :test_format, format: "json"
    assert_equal "application/json", @response.body

    get :test_format, format: "xml"
    assert_equal "application/xml", @response.body

    get :test_format
    assert_equal "text/html", @response.body
  end

  def test_request_format_kwarg_overrides_params
    get :test_format, format: "json", params: { format: "html" }
    assert_equal "application/json", @response.body
  end

  def test_request_format_kwarg_doesnt_mutate_params
    params = { foo: "bar" }.freeze

    assert_nothing_raised do
      get :test_format, format: "json", params: params
    end
  end

  def test_should_have_knowledge_of_client_side_cookie_state_even_if_they_are_not_set
    cookies["foo"] = "bar"
    get :no_op
    assert_equal "bar", cookies["foo"]
  end

  def test_cookies_should_be_escaped_properly
    cookies["foo"] = "+"
    get :render_cookie
    assert_equal "+", @response.body
  end

  def test_should_detect_if_cookie_is_deleted
    cookies["foo"] = "bar"
    get :delete_cookie
    assert_nil cookies["foo"]
  end

  def test_multiple_mixed_method_process_should_scrub_rack_input
    post :test_params, params: { id: 1, foo: "an foo" }
    assert_equal({ "id" => "1", "foo" => "an foo", "controller" => "test_case_test/test", "action" => "test_params" }, ::JSON.parse(@response.body))

    get :test_params, params: { bar: "an bar" }
    assert_equal({ "bar" => "an bar", "controller" => "test_case_test/test", "action" => "test_params" }, ::JSON.parse(@response.body))
  end

  %w(controller response request).each do |variable|
    %w(get post put delete head process).each do |method|
      define_method("test_#{variable}_missing_for_#{method}_raises_error") do
        remove_instance_variable "@#{variable}"
        begin
          send(method, :test_remote_addr)
          assert false, "expected RuntimeError, got nothing"
        rescue RuntimeError => error
          assert_match(%r{@#{variable} is nil}, error.message)
        rescue => error
          assert false, "expected RuntimeError, got #{error.class}"
        end
      end
    end
  end

  FILES_DIR = File.expand_path("../fixtures/multipart", __dir__)

  READ_BINARY = "rb:binary"
  READ_PLAIN = "r:binary"

  def test_test_uploaded_file
    filename = "ruby_on_rails.jpg"
    path = "#{FILES_DIR}/#{filename}"
    content_type = "image/png"
    expected = File.read(path)
    expected.force_encoding(Encoding::BINARY)

    file = Rack::Test::UploadedFile.new(path, content_type)
    assert_equal filename, file.original_filename
    assert_equal content_type, file.content_type
    assert_equal file.path, file.local_path
    assert_equal expected, file.read

    new_content_type = "new content_type"
    file.content_type = new_content_type
    assert_equal new_content_type, file.content_type
  end

  def test_fixture_path_is_accessed_from_self_instead_of_active_support_test_case
    TestCaseTest.stub :fixture_path, File.expand_path("../fixtures", __dir__) do
      expected = "`fixture_file_upload(\"multipart/ruby_on_rails.jpg\")` to `fixture_file_upload(\"ruby_on_rails.jpg\")`"

      assert_deprecated(expected) do
        uploaded_file = fixture_file_upload("multipart/ruby_on_rails.jpg", "image/png")
        assert_equal File.open("#{FILES_DIR}/ruby_on_rails.jpg", READ_PLAIN).read, uploaded_file.read
      end
    end
  end

  def test_test_uploaded_file_with_binary
    filename = "ruby_on_rails.jpg"
    path = "#{FILES_DIR}/#{filename}"
    content_type = "image/png"

    binary_uploaded_file = Rack::Test::UploadedFile.new(path, content_type, :binary)
    assert_equal File.open(path, READ_BINARY).read, binary_uploaded_file.read

    plain_uploaded_file = Rack::Test::UploadedFile.new(path, content_type)
    assert_equal File.open(path, READ_PLAIN).read, plain_uploaded_file.read
  end

  def test_fixture_file_upload_with_binary
    filename = "ruby_on_rails.jpg"
    path = "#{FILES_DIR}/#{filename}"
    content_type = "image/jpeg"

    binary_file_upload = fixture_file_upload(path, content_type, :binary)
    assert_equal File.open(path, READ_BINARY).read, binary_file_upload.read

    plain_file_upload = fixture_file_upload(path, content_type)
    assert_equal File.open(path, READ_PLAIN).read, plain_file_upload.read
  end

  def test_fixture_file_upload_should_be_able_access_to_tempfile
    file = fixture_file_upload(FILES_DIR + "/ruby_on_rails.jpg", "image/jpeg")
    assert_respond_to file, :tempfile
  end

  def test_fixture_file_upload
    post :test_file_upload,
      params: {
        file: fixture_file_upload(FILES_DIR + "/ruby_on_rails.jpg", "image/jpeg")
      }
    assert_equal "45142", @response.body
  end

  def test_fixture_file_upload_output_deprecation_when_file_fixture_path_is_not_set
    TestCaseTest.stub :fixture_path, File.expand_path("../fixtures", __dir__) do
      TestCaseTest.stub :file_fixture_path, nil do
        assert_deprecated(/In Rails 7.0, the path needs to be relative to `file_fixture_path`/) do
          fixture_file_upload("multipart/ruby_on_rails.jpg", "image/jpeg")
        end
      end
    end
  end

  def test_fixture_file_upload_does_not_output_deprecation_when_file_fixture_path_is_set
    TestCaseTest.stub :fixture_path, File.expand_path("../fixtures", __dir__) do
      assert_not_deprecated do
        fixture_file_upload("ruby_on_rails.jpg", "image/jpeg")
      end
    end
  end

  def test_fixture_file_upload_relative_to_fixture_path
    TestCaseTest.stub :fixture_path, File.expand_path("../fixtures", __dir__) do
      expected = "`fixture_file_upload(\"multipart/ruby_on_rails.jpg\")` to `fixture_file_upload(\"ruby_on_rails.jpg\")`"

      assert_deprecated(expected) do
        uploaded_file = fixture_file_upload("multipart/ruby_on_rails.jpg", "image/jpeg")
        assert_equal File.open("#{FILES_DIR}/ruby_on_rails.jpg", READ_PLAIN).read, uploaded_file.read
      end
    end
  end

  def test_fixture_file_upload_relative_to_fixture_path_with_relative_file_fixture_path
    TestCaseTest.stub :fixture_path, File.expand_path("../fixtures", __dir__) do
      TestCaseTest.stub :file_fixture_path, "test/fixtures/multipart" do
        expected = "`fixture_file_upload(\"multipart/ruby_on_rails.jpg\")` to `fixture_file_upload(\"ruby_on_rails.jpg\")`"

        assert_deprecated(expected) do
          uploaded_file = fixture_file_upload("multipart/ruby_on_rails.jpg", "image/jpg")
          assert_equal File.open("#{FILES_DIR}/ruby_on_rails.jpg", READ_PLAIN).read, uploaded_file.read
        end
      end
    end
  end

  def test_fixture_file_upload_ignores_fixture_path_given_full_path
    TestCaseTest.stub :fixture_path, __dir__ do
      uploaded_file = fixture_file_upload("#{FILES_DIR}/ruby_on_rails.jpg", "image/jpeg")
      assert_equal File.open("#{FILES_DIR}/ruby_on_rails.jpg", READ_PLAIN).read, uploaded_file.read
    end
  end

  def test_fixture_file_upload_ignores_nil_fixture_path
    uploaded_file = fixture_file_upload("#{FILES_DIR}/ruby_on_rails.jpg", "image/jpeg")
    assert_equal File.open("#{FILES_DIR}/ruby_on_rails.jpg", READ_PLAIN).read, uploaded_file.read
  end

  def test_action_dispatch_uploaded_file_upload
    filename = "ruby_on_rails.jpg"
    path = "#{FILES_DIR}/#{filename}"
    post :test_file_upload, params: {
      file: Rack::Test::UploadedFile.new(path, "image/jpeg", true)
    }
    assert_equal "45142", @response.body
  end

  def test_test_uploaded_file_exception_when_file_doesnt_exist
    assert_raise(RuntimeError) { Rack::Test::UploadedFile.new("non_existent_file") }
  end

  def test_redirect_url_only_cares_about_location_header
    get :create
    assert_response :created

    # Redirect URL doesn't care that it wasn't a :redirect response.
    assert_equal "/resource", @response.redirect_url
    assert_equal @response.redirect_url, redirect_to_url

    # Must be a :redirect response.
    assert_raise(ActiveSupport::TestCase::Assertion) do
      assert_redirected_to "/resource"
    end
  end

  def test_exception_in_action_reaches_test
    assert_raise(RuntimeError) do
      process :boom, method: "GET"
    end
  end

  def test_request_state_is_cleared_after_exception
    assert_raise(RuntimeError) do
      process :boom,
        method: "GET",
        params: { q: "test1" }
    end

    process :test_query_string,
      method: "GET",
      params: { q: "test2" }

    assert_equal "q=test2", @response.body
  end

  def test_parsed_body_without_as_option
    post :render_json, body: { foo: "heyo" }
    assert_equal({ "foo" => "heyo" }, response.parsed_body)
  end

  def test_parsed_body_with_as_option
    post :render_json, body: { foo: "heyo" }.to_json, as: :json
    assert_equal({ "foo" => "heyo" }, response.parsed_body)
  end
end

class ResponseDefaultHeadersTest < ActionController::TestCase
  class TestController < ActionController::Base
    def remove_header
      headers.delete params[:header]
      head :ok, "C" => "3"
    end

    # Render a head response, but don't touch default headers
    def leave_alone
      head :ok
    end
  end

  def before_setup
    @original = ActionDispatch::Response.default_headers
    @defaults = { "A" => "1", "B" => "2" }
    ActionDispatch::Response.default_headers = @defaults
    super
  end

  teardown do
    ActionDispatch::Response.default_headers = @original
  end

  def setup
    super
    @controller = TestController.new
    @request.env["PATH_INFO"] = nil
    @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
      r.draw do
        ActiveSupport::Deprecation.silence do
          get ":controller(/:action(/:id))"
        end
      end
    end
  end

  test "response contains default headers" do
    get :leave_alone

    # Response headers start out with the defaults
    assert_equal @defaults.merge("Content-Type" => "text/html"), response.headers
  end

  test "response deletes a default header" do
    get :remove_header, params: { header: "A" }
    assert_response :ok

    # After a request, the response in the test case doesn't have the
    # defaults merged on top again.
    assert_not_includes response.headers, "A"
    assert_includes response.headers, "B"
    assert_includes response.headers, "C"
  end
end

module EngineControllerTests
  class Engine < ::Rails::Engine
    isolate_namespace EngineControllerTests

    routes.draw do
      get "/" => "bar#index"
    end
  end

  class BarController < ActionController::Base
    def index
      render plain: "bar"
    end
  end

  class BarControllerTest < ActionController::TestCase
    tests BarController

    def test_engine_controller_route
      get :index
      assert_equal @response.body, "bar"
    end
  end

  class BarControllerTestWithExplicitRouteSet < ActionController::TestCase
    tests BarController

    def setup
      @routes = Engine.routes
    end

    def test_engine_controller_route
      get :index
      assert_equal @response.body, "bar"
    end
  end
end

class InferringClassNameTest < ActionController::TestCase
  def test_determine_controller_class
    assert_equal ContentController, determine_class("ContentControllerTest")
  end

  def test_determine_controller_class_with_nonsense_name
    assert_nil determine_class("HelloGoodBye")
  end

  def test_determine_controller_class_with_sensible_name_where_no_controller_exists
    assert_nil determine_class("NoControllerWithThisNameTest")
  end

  private
    def determine_class(name)
      ActionController::TestCase.determine_default_controller_class(name)
    end
end

class CrazyNameTest < ActionController::TestCase
  tests ContentController

  def test_controller_class_can_be_set_manually_not_just_inferred
    assert_equal ContentController, self.class.controller_class
  end
end

class CrazySymbolNameTest < ActionController::TestCase
  tests :content

  def test_set_controller_class_using_symbol
    assert_equal ContentController, self.class.controller_class
  end
end

class CrazyStringNameTest < ActionController::TestCase
  tests "content"

  def test_set_controller_class_using_string
    assert_equal ContentController, self.class.controller_class
  end
end

class NamedRoutesControllerTest < ActionController::TestCase
  tests ContentController

  def test_should_be_able_to_use_named_routes_before_a_request_is_done
    with_routing do |set|
      set.draw { resources :contents }
      assert_equal "http://test.host/contents/new", new_content_url
      assert_equal "http://test.host/contents/1", content_url(id: 1)
    end
  end
end

class AnonymousControllerTest < ActionController::TestCase
  def setup
    @controller = Class.new(ActionController::Base) do
      def index
        render plain: params[:controller]
      end
    end.new

    @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
      r.draw do
        ActiveSupport::Deprecation.silence do
          get ":controller(/:action(/:id))"
        end
      end
    end
  end

  def test_controller_name
    get :index
    assert_equal "anonymous", @response.body
  end
end

class RoutingDefaultsTest < ActionController::TestCase
  def setup
    @controller = Class.new(ActionController::Base) do
      def post
        render plain: request.fullpath
      end

      def project
        render plain: request.fullpath
      end
    end.new

    @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
      r.draw do
        get "/posts/:id", to: "anonymous#post", bucket_type: "post"
        get "/projects/:id", to: "anonymous#project", defaults: { bucket_type: "project" }
      end
    end
  end

  def test_route_option_can_be_passed_via_process
    get :post, params: { id: 1, bucket_type: "post" }
    assert_equal "/posts/1", @response.body
  end

  def test_route_default_is_not_required_for_building_request_uri
    get :project, params: { id: 2 }
    assert_equal "/projects/2", @response.body
  end
end
