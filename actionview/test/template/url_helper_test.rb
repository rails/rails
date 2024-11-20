# frozen_string_literal: true

require "abstract_unit"

class Workshop
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_accessor :id

  def initialize(id)
    @id = id
  end

  def persisted?
    id.present?
  end

  def to_s
    "Workshop #{id}"
  end
end

class UrlHelperTest < ActiveSupport::TestCase
  # In a few cases, the helper proxies to 'controller'
  # or request.
  #
  # In those cases, we'll set up a simple mock
  attr_accessor :controller, :request

  cattr_accessor :request_forgery, default: false

  routes = ActionDispatch::Routing::RouteSet.new
  routes.draw do
    get "/" => "foo#bar"
    get "/other" => "foo#other"
    get "/article/:id" => "foo#article", :as => :article
    get "/category/:category" => "foo#category"
    resources :sessions
    resources :workshops do
      resources :sessions
    end

    scope :engine do
      get "/" => "foo#bar"
    end
  end

  include ActionView::Helpers::UrlHelper
  include routes.url_helpers

  include ActionView::Helpers::JavaScriptHelper
  include Rails::Dom::Testing::Assertions::DomAssertions
  include ActionView::Context
  include RenderERBUtils

  setup :_prepare_context
  setup { ActionView::Helpers::UrlHelper.button_to_generates_button_tag = @button_to_generates_button_tag = true }
  teardown { ActionView::Helpers::UrlHelper.button_to_generates_button_tag = @button_to_generates_button_tag }

  def hash_for(options = {})
    { controller: "foo", action: "bar" }.merge!(options)
  end
  alias url_hash hash_for

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

  def test_to_form_params_with_hash
    assert_equal(
      [{ name: "name", value: "David" }, { name: "nationality", value: "Danish" }],
      to_form_params(name: "David", nationality: "Danish")
    )
  end

  def test_to_form_params_with_hash_having_symbol_and_string_keys
    assert_equal(
      [{ name: "name", value: "David" }, { name: "nationality", value: "Danish" }],
      to_form_params("name" => "David", :nationality => "Danish")
    )
  end

  def test_to_form_params_with_nested_hash
    assert_equal(
      [{ name: "country[name]", value: "Denmark" }],
      to_form_params(country: { name: "Denmark" })
    )
  end

  def test_to_form_params_with_array_nested_in_hash
    assert_equal(
      [{ name: "countries[]", value: "Denmark" }, { name: "countries[]", value: "Sweden" }],
      to_form_params(countries: ["Denmark", "Sweden"])
    )
  end

  def test_to_form_params_with_namespace
    assert_equal(
      [{ name: "country[name]", value: "Denmark" }],
      to_form_params({ name: "Denmark" }, "country")
    )
  end

  def test_button_to_without_protect_against_forgery_method
    self.class.undef_method(:protect_against_forgery?)
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com")
    )
  ensure
    self.class.define_method(:protect_against_forgery?) { request_forgery }
  end

  def test_button_to_with_authenticity_token
    self.request_forgery = true

    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button><input name="form_token" type="hidden" value="token" autocomplete="off" /></form>},
      button_to("Hello", "http://www.example.com", authenticity_token: "token")
    )
  ensure
    self.request_forgery = false
  end

  def test_button_to_with_authenticity_token_true
    self.request_forgery = true

    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button><input name="form_token" type="hidden" value="secret" autocomplete="off" /></form>},
      button_to("Hello", "http://www.example.com", authenticity_token: true)
    )
  ensure
    self.request_forgery = false
  end

  def test_button_to_with_authenticity_token_false
    self.request_forgery = true

    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", authenticity_token: false)
    )
  ensure
    self.request_forgery = false
  end

  def test_button_to_with_straight_url
    assert_dom_equal %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button></form>}, button_to("Hello", "http://www.example.com")
  end

  def test_button_to_with_path
    assert_dom_equal(
      %{<form method="post" action="/article/Hello" class="button_to"><button type="submit">Hello</button></form>},
      button_to("Hello", article_path("Hello"))
    )
  end

  def test_button_to_with_false_url
    assert_dom_equal(
      %{<form method="post" class="button_to"><button type="submit">Hello</button></form>},
      button_to("Hello", false)
    )
  end

  def test_button_to_with_false_url_and_block
    assert_dom_equal(
      %{<form method="post" class="button_to"><button type="submit">Hello</button></form>},
      button_to(false) { "Hello" }
    )
  end

  def test_button_to_with_new_record_model
    session = Session.new(nil)

    assert_dom_equal(
      %{<form method="post" action="/sessions" class="button_to"><button type="submit">Create Session</button></form>},
      button_to("Create Session", session)
    )
  end

  def test_button_to_with_new_record_model_and_block
    workshop = Workshop.new(nil)

    assert_dom_equal(
      %{<form method="post" action="/workshops" class="button_to"><button type="submit">Create</button></form>},
      button_to(workshop) { "Create" }
    )
  end

  def test_button_to_with_nested_new_record_model_and_block
    workshop = Workshop.new("1")
    session = Session.new(nil)

    assert_dom_equal(
      %{<form method="post" action="/workshops/1/sessions" class="button_to"><button type="submit">Create</button></form>},
      button_to([workshop, session]) { "Create" }
    )
  end

  def test_button_to_with_persisted_model
    workshop = Workshop.new("1")

    assert_dom_equal(
      %{<form method="post" action="/workshops/1" class="button_to"><input type="hidden" name="_method" value="patch" autocomplete="off" /><button type="submit">Update</button></form>},
      button_to(workshop) { "Update" }
    )
  end

  def test_button_to_with_persisted_model_and_block
    workshop = Workshop.new("1")

    assert_dom_equal(
      %{<form method="post" action="/workshops/1" class="button_to"><input type="hidden" name="_method" value="patch" autocomplete="off" /><button type="submit">Update</button></form>},
      button_to(workshop) { "Update" }
    )
  end

  def test_button_to_with_nested_persisted_model_and_block
    workshop = Workshop.new("1")
    session = Session.new("1")

    assert_dom_equal(
      %{<form method="post" action="/workshops/1/sessions/1" class="button_to"><input type="hidden" name="_method" value="patch" autocomplete="off" /><button type="submit">Update</button></form>},
      button_to([workshop, session]) { "Update" }
    )
  end

  def test_button_to_with_straight_url_and_request_forgery
    self.request_forgery = true

    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button><input name="form_token" type="hidden" value="secret" autocomplete="off" /></form>},
      button_to("Hello", "http://www.example.com")
    )
  ensure
    self.request_forgery = false
  end

  def test_button_to_with_form_class
    assert_dom_equal %{<form method="post" action="http://www.example.com" class="custom-class"><button type="submit">Hello</button></form>}, button_to("Hello", "http://www.example.com", form_class: "custom-class")
  end

  def test_button_to_with_form_class_escapes
    assert_dom_equal %{<form method="post" action="http://www.example.com" class="&lt;script&gt;evil_js&lt;/script&gt;"><button type="submit">Hello</button></form>}, button_to("Hello", "http://www.example.com", form_class: "<script>evil_js</script>")
  end

  def test_button_to_with_query
    assert_dom_equal %{<form method="post" action="http://www.example.com/q1=v1&amp;q2=v2" class="button_to"><button type="submit">Hello</button></form>}, button_to("Hello", "http://www.example.com/q1=v1&q2=v2")
  end

  def test_button_to_with_value
    assert_dom_equal %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit" name="key" value="value">Hello</button></form>}, button_to("Hello", "http://www.example.com", name: "key", value: "value")
  end

  def test_button_to_with_html_safe_URL
    assert_dom_equal %{<form method="post" action="http://www.example.com/q1=v1&amp;q2=v2" class="button_to"><button type="submit">Hello</button></form>}, button_to("Hello", raw("http://www.example.com/q1=v1&amp;q2=v2"))
  end

  def test_button_to_with_query_and_no_name
    assert_dom_equal %{<form method="post" action="http://www.example.com?q1=v1&amp;q2=v2" class="button_to"><button type="submit">http://www.example.com?q1=v1&amp;q2=v2</button></form>}, button_to(nil, "http://www.example.com?q1=v1&q2=v2")
  end

  def test_button_to_with_javascript_confirm
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button data-confirm="Are you sure?" type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", data: { confirm: "Are you sure?" })
    )
  end

  def test_button_to_with_javascript_disable_with
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button data-disable-with="Greeting..." type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", data: { disable_with: "Greeting..." })
    )
  end

  def test_button_to_with_remote_and_form_options
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="custom-class" data-remote="true" data-type="json"><button type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", remote: true, form: { class: "custom-class", "data-type" => "json" })
    )
  end

  def test_button_to_with_remote_and_javascript_confirm
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to" data-remote="true"><button data-confirm="Are you sure?" type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", remote: true, data: { confirm: "Are you sure?" })
    )
  end

  def test_button_to_with_remote_and_javascript_disable_with
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to" data-remote="true"><button data-disable-with="Greeting..." type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", remote: true, data: { disable_with: "Greeting..." })
    )
  end

  def test_button_to_with_remote_false
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", remote: false)
    )
  end

  def test_button_to_enabled_disabled
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", disabled: false)
    )
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button disabled="disabled" type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", disabled: true)
    )
  end

  def test_button_to_with_method_delete
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input type="hidden" name="_method" value="delete" autocomplete="off" /><button type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", method: :delete)
    )
  end

  def test_button_to_with_method_get
    assert_dom_equal(
      %{<form method="get" action="http://www.example.com" class="button_to"><button type="submit">Hello</button></form>},
      button_to("Hello", "http://www.example.com", method: :get)
    )
  end

  def test_button_to_with_block
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit"><span>Hello</span></button></form>},
      button_to("http://www.example.com") { content_tag(:span, "Hello") }
    )
  end

  def test_button_to_with_params
    assert_dom_equal(
      %{<form action="http://www.example.com" class="button_to" method="post"><button type="submit">Hello</button><input type="hidden" name="baz" value="quux" autocomplete="off" /><input type="hidden" name="foo" value="bar" autocomplete="off" /></form>},
      button_to("Hello", "http://www.example.com", params: { foo: :bar, baz: "quux" })
    )
  end

  def test_button_to_with_block_and_hash_url
    assert_dom_equal(
      %{<form action="/other" class="button_to" method="post"><button class="button" type="submit">Hello</button></form>},
      button_to({ controller: "foo", action: "other" }, class: "button") { "Hello" }
    )
  end

  def test_button_to_generates_input_when_button_to_generates_button_tag_false
    old_value = ActionView::Helpers::UrlHelper.button_to_generates_button_tag
    ActionView::Helpers::UrlHelper.button_to_generates_button_tag = false

    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input type="submit" value="Save"/></form>},
      button_to("Save", "http://www.example.com")
    )
  ensure
    ActionView::Helpers::UrlHelper.button_to_generates_button_tag = old_value
  end

  def test_button_to_with_content_exfiltration_prevention
    with_prepend_content_exfiltration_prevention(true) do
      assert_dom_equal(
        %{<!-- '"` --><!-- </textarea></xmp> --></option></form><form method="post" action="http://www.example.com" class="button_to"><button type="submit">Hello</button></form>},
        button_to("Hello", "http://www.example.com")
      )
    end
  end

  class FakeParams
    def initialize(permitted = true)
      @permitted = permitted
    end

    def permitted?
      @permitted
    end

    def to_h
      if permitted?
        { foo: :bar, baz: "quux" }
      else
        raise ArgumentError
      end
    end
  end

  def test_button_to_with_permitted_strong_params
    assert_dom_equal(
      %{<form action="http://www.example.com" class="button_to" method="post"><button type="submit">Hello</button><input type="hidden" name="baz" value="quux" autocomplete="off" /><input type="hidden" name="foo" value="bar" autocomplete="off" /></form>},
      button_to("Hello", "http://www.example.com", params: FakeParams.new)
    )
  end

  def test_button_to_with_unpermitted_strong_params
    assert_raises(ArgumentError) do
      button_to("Hello", "http://www.example.com", params: FakeParams.new(false))
    end
  end

  def test_button_to_with_nested_hash_params
    assert_dom_equal(
      %{<form action="http://www.example.com" class="button_to" method="post"><button type="submit">Hello</button><input type="hidden" name="foo[bar]" value="baz" autocomplete="off" /></form>},
      button_to("Hello", "http://www.example.com", params: { foo: { bar: "baz" } })
    )
  end

  def test_button_to_with_nested_array_params
    assert_dom_equal(
      %{<form action="http://www.example.com" class="button_to" method="post"><button type="submit">Hello</button><input type="hidden" name="foo[]" value="bar" autocomplete="off" /></form>},
      button_to("Hello", "http://www.example.com", params: { foo: ["bar"] })
    )
  end

  def test_link_tag_with_straight_url
    assert_dom_equal %{<a href="http://www.example.com">Hello</a>}, link_to("Hello", "http://www.example.com")
  end

  def test_link_tag_without_host_option
    assert_dom_equal(%{<a href="/">Test Link</a>}, link_to("Test Link", url_hash))
  end

  def test_link_tag_with_host_option
    hash = hash_for(host: "www.example.com")
    expected = %{<a href="http://www.example.com/">Test Link</a>}
    assert_dom_equal(expected, link_to("Test Link", hash))
  end

  def test_link_tag_with_query
    expected = %{<a href="http://www.example.com?q1=v1&amp;q2=v2">Hello</a>}
    assert_dom_equal expected, link_to("Hello", "http://www.example.com?q1=v1&q2=v2")
  end

  def test_link_tag_with_query_and_no_name
    expected = %{<a href="http://www.example.com?q1=v1&amp;q2=v2">http://www.example.com?q1=v1&amp;q2=v2</a>}
    assert_dom_equal expected, link_to(nil, "http://www.example.com?q1=v1&q2=v2")
  end

  def test_link_tag_with_back
    env = { "HTTP_REFERER" => "http://www.example.com/referer" }
    @controller = Struct.new(:request).new(Struct.new(:env).new(env))
    expected = %{<a href="#{env["HTTP_REFERER"]}">go back</a>}
    assert_dom_equal expected, link_to("go back", :back)
  end

  def test_link_tag_with_back_and_no_referer
    @controller = Struct.new(:request).new(Struct.new(:env).new({}))
    link = link_to("go back", :back)
    assert_dom_equal %{<a href="javascript:history.back()">go back</a>}, link
  end

  def test_link_tag_with_img
    link = link_to(raw("<img src='/favicon.jpg' />"), "/")
    expected = %{<a href="/"><img src='/favicon.jpg' /></a>}
    assert_dom_equal expected, link
  end

  def test_link_with_nil_html_options
    link = link_to("Hello", url_hash, nil)
    assert_dom_equal %{<a href="/">Hello</a>}, link
  end

  def test_link_tag_with_custom_onclick
    link = link_to("Hello", "http://www.example.com", onclick: "alert('yay!')")
    expected = %{<a href="http://www.example.com" onclick="alert(&#39;yay!&#39;)">Hello</a>}
    assert_dom_equal expected, link
  end

  def test_link_tag_with_javascript_confirm
    assert_dom_equal(
      %{<a href="http://www.example.com" data-confirm="Are you sure?">Hello</a>},
      link_to("Hello", "http://www.example.com", data: { confirm: "Are you sure?" })
    )
    assert_dom_equal(
      %{<a href="http://www.example.com" data-confirm="You can't possibly be sure, can you?">Hello</a>},
      link_to("Hello", "http://www.example.com", data: { confirm: "You can't possibly be sure, can you?" })
    )
    assert_dom_equal(
      %{<a href="http://www.example.com" data-confirm="You can't possibly be sure,\n can you?">Hello</a>},
      link_to("Hello", "http://www.example.com", data: { confirm: "You can't possibly be sure,\n can you?" })
    )
  end

  def test_link_to_with_remote
    assert_dom_equal(
      %{<a href="http://www.example.com" data-remote="true">Hello</a>},
      link_to("Hello", "http://www.example.com", remote: true)
    )
  end

  def test_link_to_with_remote_false
    assert_dom_equal(
      %{<a href="http://www.example.com">Hello</a>},
      link_to("Hello", "http://www.example.com", remote: false)
    )
  end

  def test_link_to_with_symbolic_remote_in_non_html_options
    assert_dom_equal(
      %{<a href="/" data-remote="true">Hello</a>},
      link_to("Hello", hash_for(remote: true), {})
    )
  end

  def test_link_to_with_string_remote_in_non_html_options
    assert_dom_equal(
      %{<a href="/" data-remote="true">Hello</a>},
      link_to("Hello", hash_for("remote" => true), {})
    )
  end

  def test_link_tag_using_post_javascript
    assert_dom_equal(
      %{<a href="http://www.example.com" data-method="post" rel="nofollow">Hello</a>},
      link_to("Hello", "http://www.example.com", method: :post)
    )
  end

  def test_link_tag_using_delete_javascript
    assert_dom_equal(
      %{<a href="http://www.example.com" rel="nofollow" data-method="delete">Destroy</a>},
      link_to("Destroy", "http://www.example.com", method: :delete)
    )
  end

  def test_link_tag_using_delete_javascript_and_href
    assert_dom_equal(
      %{<a href="\#" rel="nofollow" data-method="delete">Destroy</a>},
      link_to("Destroy", "http://www.example.com", method: :delete, href: "#")
    )
  end

  def test_link_tag_using_post_javascript_and_rel
    assert_dom_equal(
      %{<a href="http://www.example.com" data-method="post" rel="example nofollow">Hello</a>},
      link_to("Hello", "http://www.example.com", method: :post, rel: "example")
    )

    assert_dom_equal(
      %{<a href="http://www.example.com" data-method="post" rel="example nofollow">Hello</a>},
      link_to("Hello", "http://www.example.com", method: :post, rel: :example)
    )
  end

  def test_link_tag_using_post_javascript_and_confirm
    assert_dom_equal(
      %{<a href="http://www.example.com" data-method="post" rel="nofollow" data-confirm="Are you serious?">Hello</a>},
      link_to("Hello", "http://www.example.com", method: :post, data: { confirm: "Are you serious?" })
    )
  end

  def test_link_tag_using_delete_javascript_and_href_and_confirm
    assert_dom_equal(
      %{<a href="\#" rel="nofollow" data-confirm="Are you serious?" data-method="delete">Destroy</a>},
      link_to("Destroy", "http://www.example.com", method: :delete, href: "#", data: { confirm: "Are you serious?" })
    )
  end

  def test_link_tag_with_block
    assert_dom_equal %{<a href="/"><span>Example site</span></a>},
      link_to("/") { content_tag(:span, "Example site") }
  end

  def test_link_tag_with_block_and_html_options
    assert_dom_equal %{<a class="special" href="/"><span>Example site</span></a>},
      link_to("/", class: "special") { content_tag(:span, "Example site") }
  end

  def test_link_tag_using_block_and_hash
    assert_dom_equal(
      %{<a href="/"><span>Example site</span></a>},
      link_to(url_hash) { content_tag(:span, "Example site") }
    )
  end

  def test_link_tag_using_block_in_erb
    out = render_erb %{<%= link_to('/') do %>Example site<% end %>}
    assert_equal '<a href="/">Example site</a>', out
  end

  def test_link_tag_with_html_safe_string
    assert_dom_equal(
      %{<a href="/article/Gerd_M%C3%BCller">Gerd Müller</a>},
      link_to("Gerd Müller", article_path("Gerd_Müller"))
    )
  end

  def test_link_tag_escapes_content
    assert_dom_equal %{<a href="/">Malicious &lt;script&gt;content&lt;/script&gt;</a>},
      link_to("Malicious <script>content</script>", "/")
  end

  def test_link_tag_does_not_escape_html_safe_content
    assert_dom_equal %{<a href="/">Malicious <script>content</script></a>},
      link_to(raw("Malicious <script>content</script>"), "/")
  end

  def test_link_tag_using_active_record_model
    @workshop = Workshop.new(1.to_s)
    link = link_to(@workshop)
    assert_dom_equal %{<a href="/workshops/1">Workshop 1</a>}, link
  end

  def test_link_tag_using_active_record_model_twice
    @workshop = Workshop.new(1.to_s)
    link = link_to(@workshop, @workshop)
    assert_dom_equal %{<a href="/workshops/1">Workshop 1</a>}, link
  end

  def test_link_to_unless
    assert_equal "Showing", link_to_unless(true, "Showing", url_hash)

    assert_dom_equal %{<a href="/">Listing</a>},
      link_to_unless(false, "Listing", url_hash)

    assert_equal "<strong>Showing</strong>",
      link_to_unless(true, "Showing", url_hash) { |name|
        raw "<strong>#{name}</strong>"
      }

    assert_equal "test",
      link_to_unless(true, "Showing", url_hash) {
        "test"
      }

    assert_equal %{&lt;b&gt;Showing&lt;/b&gt;}, link_to_unless(true, "<b>Showing</b>", url_hash)
    assert_equal %{<a href="/">&lt;b&gt;Showing&lt;/b&gt;</a>}, link_to_unless(false, "<b>Showing</b>", url_hash)
    assert_equal %{<b>Showing</b>}, link_to_unless(true, raw("<b>Showing</b>"), url_hash)
    assert_equal %{<a href="/"><b>Showing</b></a>}, link_to_unless(false, raw("<b>Showing</b>"), url_hash)
  end

  def test_link_to_if
    assert_equal "Showing", link_to_if(false, "Showing", url_hash)
    assert_dom_equal %{<a href="/">Listing</a>}, link_to_if(true, "Listing", url_hash)
  end

  def test_link_to_if_with_block
    assert_equal "Fallback", link_to_if(false, "Showing", url_hash) { "Fallback" }
    assert_dom_equal %{<a href="/">Listing</a>}, link_to_if(true, "Listing", url_hash) { "Fallback" }
  end

  def request_for_url(url, opts = {})
    env = Rack::MockRequest.env_for("http://www.example.com#{url}", opts)
    ActionDispatch::Request.new(env)
  end

  def test_current_page_with_http_head_method
    @request = request_for_url("/", method: :head)
    assert current_page?(url_hash)
    assert current_page?("http://www.example.com/")
  end

  def test_current_page_with_simple_url
    @request = request_for_url("/")
    assert current_page?(url_hash)
    assert current_page?("http://www.example.com/")
  end

  def test_current_page_ignoring_params
    @request = request_for_url("/?order=desc&page=1")

    assert current_page?(url_hash)
    assert current_page?("http://www.example.com/")
  end

  def test_current_page_considering_params
    @request = request_for_url("/?order=desc&page=1")

    assert_not current_page?(url_hash, check_parameters: true)
    assert_not current_page?(url_hash.merge(check_parameters: true))
    assert_not current_page?(ActionController::Parameters.new(url_hash.merge(check_parameters: true)).permit!)
    assert_not current_page?("http://www.example.com/", check_parameters: true)
  end

  def test_current_page_considering_params_when_options_does_not_respond_to_to_hash
    @request = request_for_url("/?order=desc&page=1")

    assert_not current_page?(:back, check_parameters: false)
  end

  def test_current_page_when_options_given_as_keyword_arguments
    @request = request_for_url("/")

    assert current_page?(**url_hash)
  end

  def test_current_page_with_params_that_match
    @request = request_for_url("/?order=desc&page=1")

    assert current_page?(hash_for(order: "desc", page: "1"))
    assert current_page?("http://www.example.com/?order=desc&page=1")
  end

  def test_current_page_with_scope_that_match
    @request = request_for_url("/engine/")

    assert current_page?("/engine")
  end

  def test_current_page_with_escaped_params
    @request = request_for_url("/category/administra%c3%a7%c3%a3o")

    assert current_page?(controller: "foo", action: "category", category: "administração")
  end

  def test_current_page_with_escaped_params_with_different_encoding
    @request = request_for_url("/")
    @request.stub(:path, (+"/category/administra%c3%a7%c3%a3o").force_encoding(Encoding::ASCII_8BIT)) do
      assert current_page?(controller: "foo", action: "category", category: "administração")
      assert current_page?("http://www.example.com/category/administra%c3%a7%c3%a3o")
    end
  end

  def test_current_page_with_double_escaped_params
    @request = request_for_url("/category/administra%c3%a7%c3%a3o?callback_url=http%3a%2f%2fexample.com%2ffoo")

    assert current_page?(controller: "foo", action: "category", category: "administração", callback_url: "http://example.com/foo")
  end

  def test_current_page_with_trailing_slash
    @request = request_for_url("/posts")

    assert current_page?("/posts/")
    assert current_page?("http://www.example.com/posts/")
  end

  def test_current_page_with_trailing_slash_and_params
    @request = request_for_url("/posts?order=desc")

    assert current_page?("/posts/?order=desc")
    assert current_page?("http://www.example.com/posts/?order=desc")
  end

  def test_current_page_with_not_get_verb
    @request = request_for_url("/events", method: :post)

    assert_not current_page?("/events")
  end

  def test_link_unless_current
    @request = request_for_url("/")

    assert_equal "Showing",
      link_to_unless_current("Showing", url_hash)
    assert_equal "Showing",
      link_to_unless_current("Showing", "http://www.example.com/")

    @request = request_for_url("/?order=desc")

    assert_equal "Showing",
      link_to_unless_current("Showing", url_hash)
    assert_equal "Showing",
      link_to_unless_current("Showing", "http://www.example.com/")

    @request = request_for_url("/?order=desc&page=1")

    assert_equal "Showing",
      link_to_unless_current("Showing", hash_for(order: "desc", page: "1"))
    assert_equal "Showing",
      link_to_unless_current("Showing", "http://www.example.com/?order=desc&page=1")

    @request = request_for_url("/?order=desc")

    assert_equal %{<a href="/?order=asc">Showing</a>},
      link_to_unless_current("Showing", hash_for(order: :asc))
    assert_equal %{<a href="http://www.example.com/?order=asc">Showing</a>},
      link_to_unless_current("Showing", "http://www.example.com/?order=asc")

    @request = request_for_url("/?order=desc")
    assert_equal %{<a href="/?order=desc&amp;page=2\">Showing</a>},
      link_to_unless_current("Showing", hash_for(order: "desc", page: 2))
    assert_equal %{<a href="http://www.example.com/?order=desc&amp;page=2">Showing</a>},
      link_to_unless_current("Showing", "http://www.example.com/?order=desc&page=2")

    @request = request_for_url("/show")

    assert_equal %{<a href="/">Listing</a>},
      link_to_unless_current("Listing", url_hash)
    assert_equal %{<a href="http://www.example.com/">Listing</a>},
      link_to_unless_current("Listing", "http://www.example.com/")
  end

  def test_link_to_unless_with_block
    assert_dom_equal %{<a href="/">Showing</a>}, link_to_unless(false, "Showing", url_hash) { "Fallback" }
    assert_equal "Fallback", link_to_unless(true, "Listing", url_hash) { "Fallback" }
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

  def protect_against_forgery?
    request_forgery
  end

  def form_authenticity_token(**)
    "secret"
  end

  def request_forgery_protection_token
    "form_token"
  end

  private
    def with_prepend_content_exfiltration_prevention(value)
      old_value = ActionView::Helpers::ContentExfiltrationPreventionHelper.prepend_content_exfiltration_prevention
      ActionView::Helpers::ContentExfiltrationPreventionHelper.prepend_content_exfiltration_prevention = value

      yield
    ensure
      ActionView::Helpers::ContentExfiltrationPreventionHelper.prepend_content_exfiltration_prevention = old_value
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

class TasksController < ActionController::Base
  ROUTES = test_routes do
    resources :tasks
  end

  def index
    render_default
  end

  def show
    render_default
  end

  private
    def render_default
      render inline: "<%= link_to_unless_current('tasks', tasks_path) %>\n" \
        "<%= link_to_unless_current('tasks', tasks_url) %>"
    end
end

class LinkToUnlessCurrentWithControllerTest < ActionController::TestCase
  tests TasksController

  def setup
    super
    @routes = TasksController::ROUTES
  end

  def test_link_to_unless_current_to_current
    get :index
    assert_equal "tasks\ntasks", @response.body
  end

  def test_link_to_unless_current_shows_link
    get :show, params: { id: 1 }
    assert_equal %{<a href="/tasks">tasks</a>\n} +
      %{<a href="#{@request.protocol}#{@request.host_with_port}/tasks">tasks</a>},
      @response.body
  end
end

class Session
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_accessor :id, :workshop_id

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

class WorkshopsController < ActionController::Base
  ROUTES = test_routes do
    resources :workshops do
      resources :sessions
    end
  end

  def index
    @workshop = Workshop.new(nil)
    render inline: "<%= url_for(@workshop) %>\n<%= link_to('Workshop', @workshop) %>"
  end

  def show
    @workshop = Workshop.new(params[:id])
    render inline: "<%= url_for(@workshop) %>\n<%= link_to('Workshop', @workshop) %>"
  end

  def edit
    @workshop = Workshop.new(params[:id])
    render inline: "<%= current_page?(@workshop) %>"
  end
end

class SessionsController < ActionController::Base
  ROUTES = test_routes do
    resources :workshops do
      resources :sessions
    end
  end

  def index
    @workshop = Workshop.new(params[:workshop_id])
    @session = Session.new(nil)
    render inline: "<%= url_for([@workshop, @session]) %>\n<%= link_to('Session', [@workshop, @session]) %>"
  end

  def show
    @workshop = Workshop.new(params[:workshop_id])
    @session = Session.new(params[:id])
    render inline: "<%= url_for([@workshop, @session]) %>\n<%= link_to('Session', [@workshop, @session]) %>"
  end

  def edit
    @workshop = Workshop.new(params[:workshop_id])
    @session = Session.new(params[:id])
    @url = [@workshop, @session, format: params[:format]]
    render inline: "<%= url_for(@url) %>\n<%= link_to('Session', @url) %>"
  end
end

class PolymorphicControllerTest < ActionController::TestCase
  def setup
    super
    @routes = WorkshopsController::ROUTES
  end

  def test_index_resource
    @controller = WorkshopsController.new

    get :index
    assert_equal %{/workshops\n<a href="/workshops">Workshop</a>}, @response.body
  end

  def test_existing_resource
    @controller = WorkshopsController.new

    get :show, params: { id: 1 }
    assert_equal %{/workshops/1\n<a href="/workshops/1">Workshop</a>}, @response.body
  end

  def test_existing_cpk_resource
    @controller = WorkshopsController.new

    get :show, params: { id: "1-27" }
    assert_equal %{/workshops/1-27\n<a href="/workshops/1-27">Workshop</a>}, @response.body
  end

  def test_current_page_when_options_does_not_respond_to_to_hash
    @controller = WorkshopsController.new

    get :edit, params: { id: 1 }
    assert_equal "false", @response.body
  end
end

class PolymorphicSessionsControllerTest < ActionController::TestCase
  def setup
    super
    @routes = SessionsController::ROUTES
  end

  def test_new_nested_resource
    @controller = SessionsController.new

    get :index, params: { workshop_id: 1 }
    assert_equal %{/workshops/1/sessions\n<a href="/workshops/1/sessions">Session</a>}, @response.body
  end

  def test_existing_nested_resource
    @controller = SessionsController.new

    get :show, params: { workshop_id: 1, id: 1 }
    assert_equal %{/workshops/1/sessions/1\n<a href="/workshops/1/sessions/1">Session</a>}, @response.body
  end

  def test_existing_nested_resource_with_params
    @controller = SessionsController.new

    get :edit, params: { workshop_id: 1, id: 1, format: "json"  }
    assert_equal %{/workshops/1/sessions/1.json\n<a href="/workshops/1/sessions/1.json">Session</a>}, @response.body
  end
end
