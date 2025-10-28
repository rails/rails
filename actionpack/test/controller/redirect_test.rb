# frozen_string_literal: true

require "abstract_unit"
require "active_support/log_subscriber/test_helper"

class Workshop
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  OUT_OF_SCOPE_BLOCK = proc do
    raise "Not executed in controller's context" unless RedirectController === self
    request.original_url
  end

  attr_accessor :id

  def initialize(id)
    @id = id
  end

  def persisted?
    id.present?
  end

  def to_s
    id.to_s
  end
end

class RedirectController < ActionController::Base
  # empty method not used anywhere to ensure methods like
  # `status` and `location` aren't called on `redirect_to` calls
  def status; raise "Should not be called!"; end
  def location; raise "Should not be called!"; end

  def simple_redirect
    redirect_to action: "hello_world"
  end

  def redirect_with_status
    redirect_to(action: "hello_world", status: 301)
  end

  def redirect_with_status_hash
    redirect_to({ action: "hello_world" }, { status: 301 })
  end

  def redirect_with_protocol
    redirect_to action: "hello_world", protocol: "https"
  end

  def url_redirect_with_status
    redirect_to("http://www.example.com", status: :moved_permanently)
  end

  def url_redirect_with_status_hash
    redirect_to("http://www.example.com", status: 301)
  end

  def relative_url_redirect_with_status
    redirect_to("/things/stuff", status: :found)
  end

  def relative_url_redirect_with_status_hash
    redirect_to("/things/stuff", status: 301)
  end

  def redirect_back_with_status
    redirect_back_or_to "/things/stuff", status: 307
  end

  def redirect_back_with_status_and_fallback_location_to_another_host
    redirect_back_or_to "http://www.rubyonrails.org/", status: 307
  end

  def safe_redirect_back_with_status
    redirect_back_or_to "/things/stuff", status: 307, allow_other_host: false
  end

  def safe_redirect_back_with_status_and_fallback_location_to_another_host
    redirect_back_or_to "http://www.rubyonrails.org/", status: 307, allow_other_host: false
  end

  def safe_redirect_to_root
    redirect_to url_from("/")
  end

  def unsafe_redirect
    redirect_to "http://www.rubyonrails.org/"
  end

  def unsafe_redirect_back
    redirect_back_or_to "http://www.rubyonrails.org/"
  end

  def unsafe_redirect_malformed
    redirect_to "http:///www.rubyonrails.org/"
  end

  def unsafe_redirect_protocol_relative_double_slash
    redirect_to "//www.rubyonrails.org/"
  end

  def unsafe_redirect_protocol_relative_triple_slash
    redirect_to "///www.rubyonrails.org/"
  end

  def unsafe_redirect_with_illegal_http_header_value_character
    redirect_to "javascript:alert(document.domain)\b", allow_other_host: true
  end

  def only_path_redirect
    redirect_to action: "other_host", only_path: true
  end

  def safe_redirect_with_fallback
    redirect_to url_from(params[:redirect_url]) || "/fallback"
  end

  def redirect_back_with_explicit_fallback_kwarg
    redirect_back(fallback_location: "/things/stuff", status: 307)
  end

  def host_redirect
    redirect_to action: "other_host", only_path: false, host: "other.test.host"
  end

  def module_redirect
    redirect_to controller: "module_test/module_redirect", action: "hello_world"
  end

  def redirect_to_url
    redirect_to "http://www.rubyonrails.org/"
  end

  def redirect_to_url_with_stringlike
    stringlike = Object.new

    def stringlike.to_str
      "http://www.rubyonrails.org/"
    end

    redirect_to stringlike
  end

  def redirect_to_url_with_unescaped_query_string
    redirect_to "http://example.com/query?status=new"
  end

  def redirect_to_url_with_complex_scheme
    redirect_to "x-test+scheme.complex:redirect"
  end

  def redirect_to_url_with_network_path_reference
    redirect_to "//www.rubyonrails.org/"
  end

  def redirect_to_path_relative_url
    redirect_to "example.com"
  end

  def redirect_to_path_relative_url_starting_with_an_at
    redirect_to "@example.com"
  end

  def redirect_to_query_string_url
    redirect_to "?foo=bar"
  end

  def redirect_to_existing_record
    redirect_to Workshop.new(5)
  end

  def redirect_to_new_record
    redirect_to Workshop.new(nil)
  end

  def redirect_to_nil
    redirect_to nil
  end

  def redirect_to_polymorphic
    redirect_to [:internal, Workshop.new(5)]
  end

  def redirect_to_polymorphic_string_args
    redirect_to ["internal", Workshop.new(5)]
  end

  def redirect_to_params
    redirect_to ActionController::Parameters.new(status: 200, protocol: "javascript", f: "%0Aeval(name)")
  end

  def redirect_to_with_block
    redirect_to proc { "http://www.rubyonrails.org/" }
  end

  def redirect_to_with_block_and_assigns
    @url = "http://www.rubyonrails.org/"
    redirect_to proc { @url }
  end

  def redirect_to_with_block_and_options
    redirect_to proc { { action: "hello_world" } }
  end

  def redirect_to_out_of_scope_block
    redirect_to Workshop::OUT_OF_SCOPE_BLOCK
  end

  def redirect_with_header_break
    redirect_to "/lol\r\nwat"
  end

  def redirect_with_null_bytes
    redirect_to "\000/lol\r\nwat"
  end

  def redirect_to_external_with_rescue
    redirect_to "http://www.rubyonrails.org/", allow_other_host: false
  rescue ActionController::Redirecting::UnsafeRedirectError
    render plain: "caught error"
  end

  def rescue_errors(e) raise e end

  private
    def dashboard_url(id, message)
      url_for action: "dashboard", params: { "id" => id, "message" => message }
    end
end

class RedirectTest < ActionController::TestCase
  tests RedirectController

  def test_simple_redirect
    get :simple_redirect
    assert_response :redirect
    assert_equal "http://test.host/redirect/hello_world", redirect_to_url
  end

  def test_redirect_with_header_break
    get :redirect_with_header_break
    assert_response :redirect
    assert_equal "http://test.host/lolwat", redirect_to_url
  end

  def test_redirect_with_null_bytes
    get :redirect_with_null_bytes
    assert_response :redirect
    assert_equal "http://test.host/lolwat", redirect_to_url
  end

  def test_redirect_with_no_status
    get :simple_redirect
    assert_response 302
    assert_equal "http://test.host/redirect/hello_world", redirect_to_url
  end

  def test_redirect_with_status
    get :redirect_with_status
    assert_response 301
    assert_equal "http://test.host/redirect/hello_world", redirect_to_url
  end

  def test_redirect_with_status_hash
    get :redirect_with_status_hash
    assert_response 301
    assert_equal "http://test.host/redirect/hello_world", redirect_to_url
  end

  def test_redirect_with_protocol
    get :redirect_with_protocol
    assert_response 302
    assert_equal "https://test.host/redirect/hello_world", redirect_to_url
  end

  def test_url_redirect_with_status
    get :url_redirect_with_status
    assert_response 301
    assert_equal "http://www.example.com", redirect_to_url
  end

  def test_url_redirect_with_status_hash
    get :url_redirect_with_status_hash
    assert_response 301
    assert_equal "http://www.example.com", redirect_to_url
  end

  def test_relative_url_redirect_with_status
    get :relative_url_redirect_with_status
    assert_response 302
    assert_equal "http://test.host/things/stuff", redirect_to_url
  end

  def test_relative_url_redirect_with_status_hash
    get :relative_url_redirect_with_status_hash
    assert_response 301
    assert_equal "http://test.host/things/stuff", redirect_to_url
  end

  def test_relative_url_redirect_host_with_port
    request.host = "test.host:1234"
    get :relative_url_redirect_with_status
    assert_response 302
    assert_equal "http://test.host:1234/things/stuff", redirect_to_url
  end

  def test_simple_redirect_using_options
    get :host_redirect
    assert_response :redirect
    assert_redirected_to action: "other_host", only_path: false, host: "other.test.host"
  end

  def test_module_redirect
    get :module_redirect
    assert_response :redirect
    assert_redirected_to "http://test.host/module_test/module_redirect/hello_world"
  end

  def test_module_redirect_using_options
    get :module_redirect
    assert_response :redirect
    assert_redirected_to controller: "module_test/module_redirect", action: "hello_world"
  end

  def test_redirect_to_url
    get :redirect_to_url
    assert_response :redirect
    assert_redirected_to "http://www.rubyonrails.org/"
  end

  def test_redirect_to_url_with_stringlike
    get :redirect_to_url_with_stringlike
    assert_response :redirect
    assert_redirected_to "http://www.rubyonrails.org/"
  end

  def test_redirect_to_url_with_unescaped_query_string
    get :redirect_to_url_with_unescaped_query_string
    assert_response :redirect
    assert_redirected_to "http://example.com/query?status=new"
  end

  def test_redirect_to_url_with_complex_scheme
    get :redirect_to_url_with_complex_scheme
    assert_response :redirect
    assert_equal "x-test+scheme.complex:redirect", redirect_to_url
  end

  def test_redirect_to_path_relative_url
    get :redirect_to_path_relative_url
    assert_response :redirect
    assert_equal "http://test.hostexample.com", redirect_to_url
  end

  def test_redirect_to_url_with_path_relative_url_starting_with_an_at
    get :redirect_to_path_relative_url_starting_with_an_at
    assert_response :redirect
    assert_equal "http://test.host@example.com", redirect_to_url
  end

  def test_redirect_to_query_string_url
    get :redirect_to_query_string_url
    assert_response :redirect
    assert_equal "http://test.host?foo=bar", redirect_to_url
  end

  def test_redirect_to_url_with_network_path_reference
    get :redirect_to_url_with_network_path_reference
    assert_response :redirect
    assert_equal "//www.rubyonrails.org/", redirect_to_url
  end

  def test_redirect_back
    referer = "http://www.example.com/coming/from"
    @request.env["HTTP_REFERER"] = referer

    get :redirect_back_with_status

    assert_response 307
    assert_equal referer, redirect_to_url
  end

  def test_redirect_back_with_no_referer
    get :redirect_back_with_status

    assert_response 307
    assert_equal "http://test.host/things/stuff", redirect_to_url
  end

  def test_redirect_back_with_no_referer_redirects_to_another_host
    get :redirect_back_with_status_and_fallback_location_to_another_host

    assert_response 307
    assert_equal "http://www.rubyonrails.org/", redirect_to_url
  end

  def test_safe_redirect_back_from_other_host
    @request.env["HTTP_REFERER"] = "http://another.host/coming/from"
    get :safe_redirect_back_with_status

    assert_response 307
    assert_equal "http://test.host/things/stuff", redirect_to_url
  end

  def test_safe_redirect_back_from_the_same_host
    referer = "http://test.host/coming/from"
    @request.env["HTTP_REFERER"] = referer
    get :safe_redirect_back_with_status

    assert_response 307
    assert_equal referer, redirect_to_url
  end

  def test_safe_redirect_back_with_no_referer
    get :safe_redirect_back_with_status

    assert_response 307
    assert_equal "http://test.host/things/stuff", redirect_to_url
  end

  def test_safe_redirect_back_with_no_referer_redirects_to_another_host
    get :safe_redirect_back_with_status_and_fallback_location_to_another_host

    assert_response 307
    assert_equal "http://www.rubyonrails.org/", redirect_to_url
  end

  def test_safe_redirect_to_root
    get :safe_redirect_to_root

    assert_equal "http://test.host/", redirect_to_url
  end

  def test_redirect_back_with_explicit_fallback_kwarg
    referer = "http://www.example.com/coming/from"
    @request.env["HTTP_REFERER"] = referer

    get :redirect_back_with_explicit_fallback_kwarg

    assert_response 307
    assert_equal referer, redirect_to_url
  end

  def test_redirect_to_record
    with_routing do |set|
      set.draw do
        resources :workshops

        ActionDispatch.deprecator.silence do
          get ":controller/:action"
        end
      end

      get :redirect_to_existing_record
      assert_equal "http://test.host/workshops/5", redirect_to_url
      assert_redirected_to Workshop.new(5)

      get :redirect_to_new_record
      assert_equal "http://test.host/workshops", redirect_to_url
      assert_redirected_to Workshop.new(nil)
    end
  end

  def test_polymorphic_redirect
    with_routing do |set|
      set.draw do
        namespace :internal do
          resources :workshops
        end

        ActionDispatch.deprecator.silence do
          get ":controller/:action"
        end
      end

      get :redirect_to_polymorphic
      assert_equal "http://test.host/internal/workshops/5", redirect_to_url
      assert_redirected_to [:internal, Workshop.new(5)]
    end
  end

  def test_polymorphic_redirect_with_string_args
    with_routing do |set|
      set.draw do
        namespace :internal do
          resources :workshops
        end

        ActionDispatch.deprecator.silence do
          get ":controller/:action"
        end
      end

      error = assert_raises(ArgumentError) do
        get :redirect_to_polymorphic_string_args
      end
      assert_equal("Please use symbols for polymorphic route arguments.", error.message)
    end
  end

  def test_redirect_to_nil
    error = assert_raise(ActionController::ActionControllerError) do
      get :redirect_to_nil
    end
    assert_equal "Cannot redirect to nil!", error.message
  end

  def test_redirect_to_params
    error = assert_raise(ActionController::UnfilteredParameters) do
      get :redirect_to_params
    end
    assert_equal "unable to convert unpermitted parameters to hash", error.message
  end

  def test_redirect_to_with_block
    get :redirect_to_with_block
    assert_response :redirect
    assert_redirected_to "http://www.rubyonrails.org/"
  end

  def test_redirect_to_with_block_and_assigns
    get :redirect_to_with_block_and_assigns
    assert_response :redirect
    assert_redirected_to "http://www.rubyonrails.org/"
  end

  def test_redirect_to_out_of_scope_block
    get :redirect_to_out_of_scope_block
    assert_response :redirect
    assert_redirected_to "http://test.host/redirect/redirect_to_out_of_scope_block"
  end

  def test_redirect_to_with_block_and_accepted_options
    with_routing do |set|
      set.draw do
        ActionDispatch.deprecator.silence do
          get ":controller/:action"
        end
      end

      get :redirect_to_with_block_and_options

      assert_response :redirect
      assert_redirected_to "http://test.host/redirect/hello_world"
    end
  end

  def test_unsafe_redirect
    with_raise_on_open_redirects do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :unsafe_redirect
      end

      assert_equal "Unsafe redirect to \"http://www.rubyonrails.org/\", pass allow_other_host: true to redirect anyway.", error.message
    end
  end

  def test_unsafe_redirect_back
    with_raise_on_open_redirects do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :unsafe_redirect_back
      end

      assert_equal "Unsafe redirect to \"http://www.rubyonrails.org/\", pass allow_other_host: true to redirect anyway.", error.message
    end
  end

  def test_unsafe_redirect_with_malformed_url
    with_raise_on_open_redirects do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :unsafe_redirect_malformed
      end

      assert_equal "Unsafe redirect to \"http:///www.rubyonrails.org/\", pass allow_other_host: true to redirect anyway.", error.message
    end
  end

  def test_unsafe_redirect_with_protocol_relative_double_slash_url
    with_raise_on_open_redirects do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :unsafe_redirect_protocol_relative_double_slash
      end

      assert_equal "Unsafe redirect to \"//www.rubyonrails.org/\", pass allow_other_host: true to redirect anyway.", error.message
    end
  end

  def test_unsafe_redirect_with_protocol_relative_triple_slash_url
    with_raise_on_open_redirects do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :unsafe_redirect_protocol_relative_triple_slash
      end

      assert_equal "Unsafe redirect to \"///www.rubyonrails.org/\", pass allow_other_host: true to redirect anyway.", error.message
    end
  end

  def test_unsafe_redirect_with_illegal_http_header_value_character
    with_raise_on_open_redirects do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :unsafe_redirect_with_illegal_http_header_value_character
      end

      msg = "The redirect URL javascript:alert(document.domain)\b contains one or more illegal HTTP header field character. " \
        "Set of legal characters defined in https://datatracker.ietf.org/doc/html/rfc7230#section-3.2.6"

      assert_equal msg, error.message
    end
  end

  def test_only_path_redirect
    with_raise_on_open_redirects do
      get :only_path_redirect
      assert_response :redirect
      assert_redirected_to "/redirect/other_host"
    end
  end

  def test_url_from
    with_raise_on_open_redirects do
      get :safe_redirect_with_fallback, params: { redirect_url: "http://test.host/app" }
      assert_response :redirect
      assert_redirected_to "http://test.host/app"
    end
  end

  def test_url_from_fallback
    with_raise_on_open_redirects do
      get :safe_redirect_with_fallback, params: { redirect_url: "http://www.rubyonrails.org/" }
      assert_response :redirect
      assert_redirected_to "http://test.host/fallback"

      get :safe_redirect_with_fallback, params: { redirect_url: "" }
      assert_response :redirect
      assert_redirected_to "http://test.host/fallback"
    end
  end

  def test_redirect_to_instrumentation
    notification = assert_notification("redirect_to.action_controller", status: 302, location: "http://test.host/redirect/hello_world") do
      get :simple_redirect
    end

    assert_kind_of ActionDispatch::Request, notification.payload[:request]
  end

  def test_redirect_to_external_with_rescue
    get :redirect_to_external_with_rescue
    assert_response :ok
  end

  def test_redirect_to_path_relative_url_with_log
    with_path_relative_redirect(:log) do
      with_logger do |logger|
        get :redirect_to_path_relative_url
        assert_response :redirect
        assert_equal "http://test.hostexample.com", redirect_to_url
        assert_logged(/Path relative URL redirect detected: "example.com"/, logger)
      end
    end
  end

  def test_redirect_to_path_relative_url_starting_with_an_at_with_log
    with_path_relative_redirect(:log) do
      with_logger do |logger|
        get :redirect_to_path_relative_url_starting_with_an_at
        assert_response :redirect
        assert_equal "http://test.host@example.com", redirect_to_url
        assert_logged(/Path relative URL redirect detected: "@example.com"/, logger)
      end
    end
  end

  def test_redirect_to_path_relative_url_starting_with_an_at_with_notify
    with_path_relative_redirect(:notify) do
      events = []
      ActiveSupport::Notifications.subscribe("unsafe_redirect.action_controller") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      get :redirect_to_path_relative_url_starting_with_an_at

      assert_response :redirect
      assert_equal "http://test.host@example.com", redirect_to_url

      assert_equal 1, events.size
      event = events.first
      assert_equal "@example.com", event.payload[:url]
      assert_equal 'Path relative URL redirect detected: "@example.com"', event.payload[:message]
      assert_kind_of Array, event.payload[:stack_trace]
      assert event.payload[:stack_trace].any? { |line| line.include?("redirect_to_path_relative_url_starting_with_an_at") }
    ensure
      ActiveSupport::Notifications.unsubscribe("unsafe_redirect.action_controller")
    end
  end

  def test_redirect_to_path_relative_url_with_notify
    with_path_relative_redirect(:notify) do
      events = []
      ActiveSupport::Notifications.subscribe("unsafe_redirect.action_controller") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      get :redirect_to_path_relative_url

      assert_response :redirect
      assert_equal "http://test.hostexample.com", redirect_to_url

      assert_equal 1, events.size
      event = events.first
      assert_equal "example.com", event.payload[:url]
      assert_equal 'Path relative URL redirect detected: "example.com"', event.payload[:message]
      assert_kind_of Array, event.payload[:stack_trace]
      assert event.payload[:stack_trace].any? { |line| line.include?("redirect_to_path_relative_url") }
    ensure
      ActiveSupport::Notifications.unsubscribe("unsafe_redirect.action_controller")
    end
  end

  def test_redirect_to_path_relative_url_with_raise
    with_path_relative_redirect(:raise) do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :redirect_to_path_relative_url
      end

      assert_equal 'Path relative URL redirect detected: "example.com"', error.message
    end
  end

  def test_redirect_to_path_relative_url_starting_with_an_at_with_raise
    with_path_relative_redirect(:raise) do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :redirect_to_path_relative_url_starting_with_an_at
      end

      assert_equal 'Path relative URL redirect detected: "@example.com"', error.message
    end
  end

  def test_redirect_to_absolute_url_does_not_log
    with_path_relative_redirect(:log) do
      with_logger do |logger|
        get :redirect_to_url
        assert_response :redirect
        assert_equal "http://www.rubyonrails.org/", redirect_to_url
        assert_not_logged(/Path relative URL redirect detected/, logger)
      end

      with_logger do |logger|
        get :relative_url_redirect_with_status
        assert_response :redirect
        assert_equal "http://test.host/things/stuff", redirect_to_url
        assert_empty logger.logged(:warn)
      end
    end
  end

  def test_redirect_to_absolute_url_does_not_notify
    with_path_relative_redirect(:notify) do
      events = []
      ActiveSupport::Notifications.subscribe("unsafe_redirect.action_controller") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      get :redirect_to_url
      assert_response :redirect
      assert_equal "http://www.rubyonrails.org/", redirect_to_url
      assert_empty events

      get :relative_url_redirect_with_status
      assert_response :redirect
      assert_equal "http://test.host/things/stuff", redirect_to_url
      assert_empty events
    ensure
      ActiveSupport::Notifications.unsubscribe("unsafe_redirect.action_controller")
    end
  end

  def test_redirect_to_absolute_url_does_not_raise
    with_path_relative_redirect(:raise) do
      get :redirect_to_url
      assert_response :redirect
      assert_equal "http://www.rubyonrails.org/", redirect_to_url

      get :relative_url_redirect_with_status
      assert_response :redirect
      assert_equal "http://test.host/things/stuff", redirect_to_url

      get :redirect_to_url_with_network_path_reference
      assert_response :redirect
      assert_equal "//www.rubyonrails.org/", redirect_to_url
    end
  end

  def test_redirect_to_query_string_url_does_not_trigger_path_relative_warning_with_log
    with_path_relative_redirect(:log) do
      with_logger do |logger|
        get :redirect_to_query_string_url
        assert_response :redirect
        assert_equal "http://test.host?foo=bar", redirect_to_url
        assert_not_logged(/Path relative URL redirect detected/, logger)
      end
    end
  end

  def test_redirect_to_query_string_url_does_not_trigger_path_relative_warning_with_notify
    with_path_relative_redirect(:notify) do
      events = []
      ActiveSupport::Notifications.subscribe("unsafe_redirect.action_controller") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      get :redirect_to_query_string_url
      assert_response :redirect
      assert_equal "http://test.host?foo=bar", redirect_to_url

      assert_empty events.select { |e| e.payload[:message]&.include?("Path relative URL redirect detected") }
    ensure
      ActiveSupport::Notifications.unsubscribe("unsafe_redirect.action_controller")
    end
  end

  def test_redirect_to_query_string_url_does_not_trigger_path_relative_warning_with_raise
    with_path_relative_redirect(:raise) do
      get :redirect_to_query_string_url
      assert_response :redirect
      assert_equal "http://test.host?foo=bar", redirect_to_url
    end
  end

  def test_redirect_with_allowed_redirect_hosts
    with_raise_on_open_redirects do
      with_allowed_redirect_hosts(hosts: ["www.rubyonrails.org"]) do
        get :redirect_to_url
        assert_response :redirect
        assert_redirected_to "http://www.rubyonrails.org/"
      end
    end
  end

  def test_not_redirect_with_allowed_redirect_hosts
    with_raise_on_open_redirects do
      with_allowed_redirect_hosts(hosts: ["www.ruby-lang.org"]) do
        assert_raise ActionController::Redirecting::UnsafeRedirectError do
          get :redirect_to_url
        end
      end
    end
  end

  def test_redirect_to_external_with_action_on_open_redirect_log
    with_action_on_open_redirect(:log) do
      with_logger do |logger|
        get :redirect_to_url
        assert_response :redirect
        assert_equal "http://www.rubyonrails.org/", redirect_to_url
        assert_logged(/Open redirect to "http:\/\/www.rubyonrails.org\/" detected/, logger)
      end
    end
  end

  def test_redirect_to_external_with_action_on_open_redirect_notify
    with_action_on_open_redirect(:notify) do
      events = []
      ActiveSupport::Notifications.subscribe("open_redirect.action_controller") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      get :redirect_to_url
      assert_response :redirect
      assert_equal "http://www.rubyonrails.org/", redirect_to_url

      assert_equal 1, events.size
      event = events.first
      assert_equal "http://www.rubyonrails.org/", event.payload[:location]
      assert_kind_of ActionDispatch::Request, event.payload[:request]
      assert_kind_of Array, event.payload[:stack_trace]
    ensure
      ActiveSupport::Notifications.unsubscribe("open_redirect.action_controller")
    end
  end

  def test_redirect_to_external_with_action_on_open_redirect_raise
    with_action_on_open_redirect(:raise) do
      error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
        get :redirect_to_url
      end
      assert_equal "Unsafe redirect to \"http://www.rubyonrails.org/\", pass allow_other_host: true to redirect anyway.", error.message
    end
  end

  def test_redirect_to_external_with_explicit_allow_other_host_false_always_raises
    with_action_on_open_redirect(:log) do
      get :redirect_to_external_with_rescue
      assert_response :ok
      assert_equal "caught error", response.body
    end

    with_action_on_open_redirect(:notify) do
      get :redirect_to_external_with_rescue
      assert_response :ok
      assert_equal "caught error", response.body
    end

    with_action_on_open_redirect(:raise) do
      get :redirect_to_external_with_rescue
      assert_response :ok
      assert_equal "caught error", response.body
    end
  end

  def test_redirect_back_with_external_referer_and_action_on_open_redirect_log
    with_action_on_open_redirect(:log) do
      @request.env["HTTP_REFERER"] = "http://www.rubyonrails.org/"
      get :redirect_back_with_status
      assert_response 307
      assert_equal "http://www.rubyonrails.org/", redirect_to_url
    end
  end

  def test_redirect_back_with_external_referer_and_action_on_open_redirect_notify
    with_action_on_open_redirect(:notify) do
      @request.env["HTTP_REFERER"] = "http://www.rubyonrails.org/"
      get :redirect_back_with_status
      assert_response 307
      assert_equal "http://www.rubyonrails.org/", redirect_to_url
    end
  end

  def test_redirect_back_with_external_referer_and_action_on_open_redirect_raise
    with_action_on_open_redirect(:raise) do
      @request.env["HTTP_REFERER"] = "http://www.rubyonrails.org/"
      get :redirect_back_with_status
      assert_response 307
      assert_equal "http://test.host/things/stuff", redirect_to_url
    end
  end

  def test_redirect_back_with_external_referer_and_explicit_allow_other_host_false
    with_action_on_open_redirect(:log) do
      @request.env["HTTP_REFERER"] = "http://another.host/coming/from"
      get :safe_redirect_back_with_status
      assert_response 307
      assert_equal "http://test.host/things/stuff", redirect_to_url
    end
  end

  def test_raise_on_open_redirects_overrides_action_on_open_redirect
    with_action_on_open_redirect(:log) do
      with_raise_on_open_redirects do
        error = assert_raise(ActionController::Redirecting::UnsafeRedirectError) do
          get :redirect_to_url
        end
        assert_match(/Unsafe redirect/, error.message)
      end
    end
  end

  def test_action_on_open_redirect_does_not_affect_internal_redirects
    with_action_on_open_redirect(:raise) do
      get :simple_redirect
      assert_response :redirect
      assert_equal "http://test.host/redirect/hello_world", redirect_to_url
    end
  end

  def test_action_on_open_redirect_with_allowed_redirect_hosts
    with_action_on_open_redirect(:raise) do
      with_allowed_redirect_hosts(hosts: ["www.rubyonrails.org"]) do
        get :redirect_to_url
        assert_response :redirect
        assert_redirected_to "http://www.rubyonrails.org/"
      end
    end
  end

  private
    def with_logger
      logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
      old_logger = ActionController::Base.logger
      ActionController::Base.logger = logger
      yield logger
    ensure
      ActionController::Base.logger = old_logger
    end

    def assert_logged(pattern, logger)
      assert logger.logged(:warn).any? { |msg| msg.match?(pattern) },
        "Expected to find log matching #{pattern.inspect} in: #{logger.logged(:warn).inspect}"
    end

    def assert_not_logged(pattern, logger)
      assert logger.logged(:warn).none? { |msg| msg.match?(pattern) },
        "Expected not to find log matching #{pattern.inspect} in: #{logger.logged(:warn).inspect}"
    end

    def with_path_relative_redirect(action)
      old_config = ActionController::Base.action_on_path_relative_redirect
      ActionController::Base.action_on_path_relative_redirect = action
      yield
    ensure
      ActionController::Base.action_on_path_relative_redirect = old_config
    end

    def with_raise_on_open_redirects
      old_raise_on_open_redirects = ActionController::Base.raise_on_open_redirects
      ActionController::Base.raise_on_open_redirects = true
      yield
    ensure
      ActionController::Base.raise_on_open_redirects = old_raise_on_open_redirects
    end

    def with_action_on_open_redirect(action)
      old_action = ActionController::Base.action_on_open_redirect
      ActionController::Base.action_on_open_redirect = action
      yield
    ensure
      ActionController::Base.action_on_open_redirect = old_action
    end

    def with_allowed_redirect_hosts(hosts:)
      old_allowed_redirect_hosts = ActionController::Base.allowed_redirect_hosts
      ActionController::Base.allowed_redirect_hosts = hosts
      yield
    ensure
      ActionController::Base.allowed_redirect_hosts = old_allowed_redirect_hosts
    end
end

module ModuleTest
  class ModuleRedirectController < ::RedirectController
    def module_redirect
      redirect_to controller: "/redirect", action: "hello_world"
    end
  end

  class ModuleRedirectTest < ActionController::TestCase
    tests ModuleRedirectController

    def test_simple_redirect
      get :simple_redirect
      assert_response :redirect
      assert_equal "http://test.host/module_test/module_redirect/hello_world", redirect_to_url
    end

    def test_simple_redirect_using_options
      get :host_redirect
      assert_response :redirect
      assert_redirected_to action: "other_host", only_path: false, host: "other.test.host"
    end

    def test_module_redirect
      get :module_redirect
      assert_response :redirect
      assert_equal "http://test.host/redirect/hello_world", redirect_to_url
    end

    def test_module_redirect_using_options
      get :module_redirect
      assert_response :redirect
      assert_redirected_to controller: "/redirect", action: "hello_world"
    end
  end
end
