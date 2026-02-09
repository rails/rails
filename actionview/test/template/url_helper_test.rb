# frozen_string_literal: true

require "abstract_unit"

class UrlHelperTest < ActiveSupport::TestCase
  # In a few cases, the helper proxies to 'controller'
  # or request.
  #
  # In those cases, we'll set up a simple mock
  attr_accessor :controller, :request

  routes = ActionDispatch::Routing::RouteSet.new
  routes.draw do
    get "/" => "foo#bar"
    get "/other" => "foo#other"
  end

  include ActionView::Helpers::UrlHelper
  include routes.url_helpers

  include Rails::Dom::Testing::Assertions::DomAssertions
  include RenderERBUtils

  def hash_for(options = {})
    { controller: "foo", action: "bar" }.merge!(options)
  end

  def test_url_for_does_not_escape_urls
    assert_equal "/?a=b&c=d", url_for(hash_for(a: :b, c: :d))
  end

  def test_url_for_does_not_include_empty_hashes
    assert_equal "/", url_for(hash_for(a: {}))
  end

  def test_url_for_with_back
    referer = "http://www.example.com/referer"
    @controller = Struct.new(:request).new(Struct.new(:env).new({ "HTTP_REFERER" => referer }))

    assert_equal "http://www.example.com/referer", url_for(:back)
  end

  def test_url_for_with_back_and_no_referer
    @controller = Struct.new(:request).new(Struct.new(:env).new({}))
    assert_equal "javascript:history.back()", url_for(:back)
  end

  def test_url_for_with_back_and_no_controller
    @controller = nil
    assert_equal "javascript:history.back()", url_for(:back)
  end

  def test_url_for_with_back_and_javascript_referer
    referer = "javascript:alert(document.cookie)"
    @controller = Struct.new(:request).new(Struct.new(:env).new({ "HTTP_REFERER" => referer }))
    assert_equal "javascript:history.back()", url_for(:back)
  end

  def test_url_for_with_invalid_referer
    referer = "THIS IS NOT A URL"
    @controller = Struct.new(:request).new(Struct.new(:env).new({ "HTTP_REFERER" => referer }))
    assert_equal "javascript:history.back()", url_for(:back)
  end

  def test_url_for_with_array_defaults_to_only_path_true
    assert_equal "/other", url_for([:other, { controller: "foo" }])
  end

  def test_url_for_with_array_and_only_path_set_to_false
    default_url_options[:host] = "http://example.com"
    assert_equal "http://example.com/other", url_for([:other, { controller: "foo", only_path: false }])
  end

  def test_mail_to
    assert_dom_equal %{<a href="mailto:david@loudthinking.com">david@loudthinking.com</a>}, mail_to("david@loudthinking.com")
    assert_dom_equal %{<a href="mailto:david@loudthinking.com">David Heinemeier Hansson</a>}, mail_to("david@loudthinking.com", "David Heinemeier Hansson")
    assert_dom_equal(
      %{<a class="admin" href="mailto:david@loudthinking.com">David Heinemeier Hansson</a>},
      mail_to("david@loudthinking.com", "David Heinemeier Hansson", "class" => "admin")
    )
    assert_equal mail_to("david@loudthinking.com", "David Heinemeier Hansson", "class" => "admin"),
                 mail_to("david@loudthinking.com", "David Heinemeier Hansson", class: "admin")
  end

  def test_mail_to_with_special_characters
    assert_dom_equal(
      %{<a href="mailto:%23%21%24%25%26%27%2A%2B-%2F%3D%3F%5E_%60%7B%7D%7C@example.org">#!$%&amp;&#39;*+-/=?^_`{}|@example.org</a>},
      mail_to("#!$%&'*+-/=?^_`{}|@example.org")
    )
  end

  def test_mail_to_with_options
    assert_dom_equal(
      %{<a href="mailto:me@example.com?cc=ccaddress%40example.com&amp;bcc=bccaddress%40example.com&amp;body=This%20is%20the%20body%20of%20the%20message.&amp;subject=This%20is%20an%20example%20email&amp;reply-to=foo%40bar.com">My email</a>},
      mail_to("me@example.com", "My email", cc: "ccaddress@example.com", bcc: "bccaddress@example.com", subject: "This is an example email", body: "This is the body of the message.", reply_to: "foo@bar.com")
    )

    assert_dom_equal(
      %{<a href="mailto:me@example.com?cc=ccaddress%40example.com&amp;bcc=bccaddress%40example.com&amp;body=This%20is%20the%20body%20of%20the%20message.&amp;subject=This%20is%20an%20example%20email&amp;reply-to=foo%40bar.com">me@example.com</a>},
      mail_to("me@example.com", cc: "ccaddress@example.com", bcc: "bccaddress@example.com", subject: "This is an example email", body: "This is the body of the message.", reply_to: "foo@bar.com")
    )

    assert_dom_equal(
      %{<a href="mailto:me@example.com?body=This%20is%20the%20body%20of%20the%20message.&amp;subject=This%20is%20an%20example%20email">My email</a>},
      mail_to("me@example.com", "My email", cc: "", bcc: "", subject: "This is an example email", body: "This is the body of the message.")
    )
  end

  def test_mail_to_with_img
    assert_dom_equal %{<a href="mailto:feedback@example.com"><img src="/feedback.png" /></a>},
      mail_to("feedback@example.com", raw('<img src="/feedback.png" />'))
  end

  def test_mail_to_with_html_safe_string
    assert_dom_equal(
      %{<a href="mailto:david@loudthinking.com">david@loudthinking.com</a>},
      mail_to(raw("david@loudthinking.com"))
    )
  end

  def test_mail_to_with_nil
    assert_dom_equal(
      %{<a href="mailto:"></a>},
      mail_to(nil)
    )
  end

  def test_mail_to_returns_html_safe_string
    assert_predicate mail_to("david@loudthinking.com"), :html_safe?
  end

  def test_mail_to_with_block
    assert_dom_equal %{<a href="mailto:me@example.com"><span>Email me</span></a>},
      mail_to("me@example.com") { content_tag(:span, "Email me") }
  end

  def test_mail_to_with_block_and_options
    assert_dom_equal %{<a class="special" href="mailto:me@example.com?cc=ccaddress%40example.com"><span>Email me</span></a>},
      mail_to("me@example.com", cc: "ccaddress@example.com", class: "special") { content_tag(:span, "Email me") }
  end

  def test_mail_to_does_not_modify_html_options_hash
    options = { class: "special" }
    mail_to "me@example.com", "ME!", options
    assert_equal({ class: "special" }, options)
  end

  def test_sms_to
    assert_dom_equal %{<a href="sms:15155555785;">15155555785</a>}, sms_to("15155555785")
    assert_dom_equal %{<a href="sms:15155555785;">Jim Jones</a>}, sms_to("15155555785", "Jim Jones")
    assert_dom_equal(
      %{<a class="admin" href="sms:15155555785;">Jim Jones</a>},
      sms_to("15155555785", "Jim Jones", "class" => "admin")
    )
    assert_equal sms_to("15155555785", "Jim Jones", "class" => "admin"),
                 sms_to("15155555785", "Jim Jones", class: "admin")
  end

  def test_sms_to_with_options
    assert_dom_equal(
      %{<a class="simple-class" href="sms:+015155555785;?&body=Hello%20from%20Jim">Text me</a>},
      sms_to("5155555785", "Text me", class: "simple-class", country_code: "01", body: "Hello from Jim")
    )

    assert_dom_equal(
      %{<a class="simple-class" href="sms:+015155555785;?&body=Hello%20from%20Jim">5155555785</a>},
      sms_to("5155555785", class: "simple-class", country_code: "01", body: "Hello from Jim")
    )

    assert_dom_equal(
      %{<a href="sms:5155555785;?&body=This%20is%20the%20body%20of%20the%20message.">Text me</a>},
      sms_to("5155555785", "Text me", body: "This is the body of the message.")
    )
  end

  def test_sms_to_with_img
    assert_dom_equal %{<a href="sms:15155555785;"><img src="/feedback.png" /></a>},
      sms_to("15155555785", raw('<img src="/feedback.png" />'))
  end

  def test_sms_to_with_html_safe_string
    assert_dom_equal(
      %{<a href="sms:1%2B5155555785;">1+5155555785</a>},
      sms_to(raw("1+5155555785"))
    )
  end

  def test_sms_to_with_nil
    assert_dom_equal(
      %{<a href="sms:;"></a>},
      sms_to(nil)
    )
  end

  def test_sms_to_returns_html_safe_string
    assert_predicate sms_to("15155555785"), :html_safe?
  end

  def test_sms_to_with_block
    assert_dom_equal %{<a href="sms:15155555785;"><span>Text me</span></a>},
      sms_to("15155555785") { content_tag(:span, "Text me") }
  end

  def test_sms_to_with_block_and_options
    assert_dom_equal %{<a class="special" href="sms:15155555785;?&body=Hello%20from%20Jim"><span>Text me</span></a>},
      sms_to("15155555785", body: "Hello from Jim", class: "special") { content_tag(:span, "Text me") }
  end

  def test_sms_to_does_not_modify_html_options_hash
    options = { class: "special" }
    sms_to "15155555785", "ME!", options
    assert_equal({ class: "special" }, options)
  end

  def test_phone_to
    assert_dom_equal %{<a href="tel:1234567890">1234567890</a>},
      phone_to("1234567890")
    assert_dom_equal %{<a href="tel:1234567890">Bob</a>},
      phone_to("1234567890", "Bob")
    assert_dom_equal(
      %{<a class="phoner" href="tel:1234567890">Bob</a>},
      phone_to("1234567890", "Bob", "class" => "phoner")
    )
    assert_equal phone_to("1234567890", "Bob", "class" => "admin"),
                 phone_to("1234567890", "Bob", class: "admin")
  end

  def test_phone_to_with_options
    assert_dom_equal(
      %{<a class="example-class" href="tel:+011234567890">Phone</a>},
      phone_to("1234567890", "Phone", class: "example-class", country_code: "01")
    )

    assert_dom_equal(
      %{<a class="example-class" href="tel:+011234567890">1234567890</a>},
      phone_to("1234567890", class: "example-class", country_code: "01")
    )

    assert_dom_equal(
      %{<a href="tel:+011234567890">Phone</a>},
      phone_to("1234567890", "Phone", country_code: "01")
    )
  end

  def test_phone_to_with_img
    assert_dom_equal %{<a href="tel:1234567890"><img src="/feedback.png" /></a>},
      phone_to("1234567890", raw('<img src="/feedback.png" />'))
  end

  def test_phone_to_with_html_safe_string
    assert_dom_equal(
      %{<a href="tel:1%2B234567890">1+234567890</a>},
      phone_to(raw("1+234567890"))
    )
  end

  def test_phone_to_with_nil
    assert_dom_equal(
      %{<a href="tel:"></a>},
      phone_to(nil)
    )
  end

  def test_phone_to_returns_html_safe_string
    assert_predicate phone_to("1234567890"), :html_safe?
  end

  def test_phone_to_with_block
    assert_dom_equal %{<a href="tel:1234567890"><span>Phone</span></a>},
      phone_to("1234567890") { content_tag(:span, "Phone") }
  end

  def test_phone_to_with_block_and_options
    assert_dom_equal %{<a class="special" href="tel:+011234567890"><span>Phone</span></a>},
      phone_to("1234567890", country_code: "01", class: "special") { content_tag(:span, "Phone") }
  end

  def test_phone_to_does_not_modify_html_options_hash
    options = { class: "special" }
    phone_to "1234567890", "ME!", options
    assert_equal({ class: "special" }, options)
  end
end

class UrlHelperControllerTest < ActionController::TestCase
  class UrlHelperController < ActionController::Base
    ROUTES = test_routes do
      get "url_helper_controller_test/url_helper/show/:id",
        to: "url_helper_controller_test/url_helper#show",
        as: :show

      get "url_helper_controller_test/url_helper/profile/:name",
        to: "url_helper_controller_test/url_helper#show",
        as: :profile

      get "url_helper_controller_test/url_helper/show_named_route",
        to: "url_helper_controller_test/url_helper#show_named_route",
        as: :show_named_route

      ActionDispatch.deprecator.silence do
        get "/:controller(/:action(/:id))"
      end

      get "url_helper_controller_test/url_helper/normalize_recall_params",
        to: UrlHelperController.action(:normalize_recall),
        as: :normalize_recall_params

      get "/url_helper_controller_test/url_helper/override_url_helper/default",
        to: "url_helper_controller_test/url_helper#override_url_helper",
        as: :override_url_helper
    end

    def show
      if params[:name]
        render inline: "ok"
      else
        redirect_to profile_path(params[:id])
      end
    end

    def show_url_for
      render inline: "<%= url_for controller: 'url_helper_controller_test/url_helper', action: 'show_url_for' %>"
    end

    def show_named_route
      render inline: "<%= show_named_route_#{params[:kind]} %>"
    end

    def nil_url_for
      render inline: "<%= url_for(nil) %>"
    end

    def normalize_recall_params
      render inline: "<%= normalize_recall_params_path %>"
    end

    def recall_params_not_changed
      render inline: "<%= url_for(action: :show_url_for) %>"
    end

    def override_url_helper
      render inline: "<%= override_url_helper_path %>"
    end

    def override_url_helper_path
      "/url_helper_controller_test/url_helper/override_url_helper/override"
    end
    helper_method :override_url_helper_path
  end

  def setup
    super
    @routes = UrlHelperController::ROUTES
  end

  tests UrlHelperController

  def test_url_for_shows_only_path
    get :show_url_for
    assert_equal "/url_helper_controller_test/url_helper/show_url_for", @response.body
  end

  def test_named_route_url_shows_host_and_path
    get :show_named_route, params: { kind: "url" }
    assert_equal "http://test.host/url_helper_controller_test/url_helper/show_named_route",
      @response.body
  end

  def test_named_route_path_shows_only_path
    get :show_named_route, params: { kind: "path" }
    assert_equal "/url_helper_controller_test/url_helper/show_named_route", @response.body
  end

  def test_url_for_nil_returns_current_path
    get :nil_url_for
    assert_equal "/url_helper_controller_test/url_helper/nil_url_for", @response.body
  end

  def test_named_route_should_show_host_and_path_using_controller_default_url_options
    class << @controller
      def default_url_options
        { host: "testtwo.host" }
      end
    end

    get :show_named_route, params: { kind: "url" }
    assert_equal "http://testtwo.host/url_helper_controller_test/url_helper/show_named_route", @response.body
  end

  def test_recall_params_should_be_normalized
    get :normalize_recall_params
    assert_equal "/url_helper_controller_test/url_helper/normalize_recall_params", @response.body
  end

  def test_recall_params_should_not_be_changed
    get :recall_params_not_changed
    assert_equal "/url_helper_controller_test/url_helper/show_url_for", @response.body
  end

  def test_recall_params_should_normalize_id
    get :show, params: { id: "123" }
    assert_equal 302, @response.status
    assert_equal "http://test.host/url_helper_controller_test/url_helper/profile/123", @response.location

    get :show, params: { name: "123" }
    assert_equal "ok", @response.body
  end

  def test_url_helper_can_be_overridden
    get :override_url_helper
    assert_equal "/url_helper_controller_test/url_helper/override_url_helper/override", @response.body
  end
end
