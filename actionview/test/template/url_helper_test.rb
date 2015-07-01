require 'abstract_unit'
require 'minitest/mock'

class UrlHelperTest < ActiveSupport::TestCase

  # In a few cases, the helper proxies to 'controller'
  # or request.
  #
  # In those cases, we'll set up a simple mock
  attr_accessor :controller, :request

  cattr_accessor :request_forgery
  self.request_forgery = false

  routes = ActionDispatch::Routing::RouteSet.new
  routes.draw do
    get "/" => "foo#bar"
    get "/other" => "foo#other"
    get "/article/:id" => "foo#article", :as => :article
    get "/category/:category" => "foo#category"
  end

  include ActionView::Helpers::UrlHelper
  include routes.url_helpers

  include ActionView::Helpers::JavaScriptHelper
  include Rails::Dom::Testing::Assertions::DomAssertions
  include ActionView::Context
  include RenderERBUtils

  setup :_prepare_context

  def hash_for(options = {})
    { controller: "foo", action: "bar" }.merge!(options)
  end
  alias url_hash hash_for

  def test_url_for_does_not_escape_urls
    assert_equal "/?a=b&c=d", url_for(hash_for(a: :b, c: :d))
  end

  def test_url_for_with_back
    referer = 'http://www.example.com/referer'
    @controller = Struct.new(:request).new(Struct.new(:env).new("HTTP_REFERER" => referer))

    assert_equal 'http://www.example.com/referer', url_for(:back)
  end

  def test_url_for_with_back_and_no_referer
    @controller = Struct.new(:request).new(Struct.new(:env).new({}))
    assert_equal 'javascript:history.back()', url_for(:back)
  end

  def test_button_to_with_straight_url
    assert_dom_equal %{<form method="post" action="http://www.example.com" class="button_to"><input type="submit" value="Hello" /></form>}, button_to("Hello", "http://www.example.com")
  end

  def test_button_to_with_path
    assert_dom_equal(
      %{<form method="post" action="/article/Hello" class="button_to"><input type="submit" value="Hello" /></form>},
      button_to("Hello", article_path("Hello".html_safe))
    )
  end

  def test_button_to_with_straight_url_and_request_forgery
    self.request_forgery = true

    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input type="submit" value="Hello" /><input name="form_token" type="hidden" value="secret" /></form>},
      button_to("Hello", "http://www.example.com")
    )
  ensure
    self.request_forgery = false
  end

  def test_button_to_with_form_class
    assert_dom_equal %{<form method="post" action="http://www.example.com" class="custom-class"><input type="submit" value="Hello" /></form>}, button_to("Hello", "http://www.example.com", form_class: 'custom-class')
  end

  def test_button_to_with_form_class_escapes
    assert_dom_equal %{<form method="post" action="http://www.example.com" class="&lt;script&gt;evil_js&lt;/script&gt;"><input type="submit" value="Hello" /></form>}, button_to("Hello", "http://www.example.com", form_class: '<script>evil_js</script>')
  end

  def test_button_to_with_query
    assert_dom_equal %{<form method="post" action="http://www.example.com/q1=v1&amp;q2=v2" class="button_to"><input type="submit" value="Hello" /></form>}, button_to("Hello", "http://www.example.com/q1=v1&q2=v2")
  end

  def test_button_to_with_html_safe_URL
    assert_dom_equal %{<form method="post" action="http://www.example.com/q1=v1&amp;q2=v2" class="button_to"><input type="submit" value="Hello" /></form>}, button_to("Hello", "http://www.example.com/q1=v1&amp;q2=v2".html_safe)
  end

  def test_button_to_with_query_and_no_name
    assert_dom_equal %{<form method="post" action="http://www.example.com?q1=v1&amp;q2=v2" class="button_to"><input type="submit" value="http://www.example.com?q1=v1&amp;q2=v2" /></form>}, button_to(nil, "http://www.example.com?q1=v1&q2=v2")
  end

  def test_button_to_with_javascript_confirm
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input data-confirm="Are you sure?" type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", data: { confirm: "Are you sure?" })
    )
  end

  def test_button_to_with_javascript_disable_with
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input data-disable-with="Greeting..." type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", data: { disable_with: "Greeting..." })
    )
  end

  def test_button_to_with_remote_and_form_options
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="custom-class" data-remote="true" data-type="json"><input type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", remote: true, form: { class: "custom-class", "data-type" => "json" })
    )
  end

  def test_button_to_with_remote_and_javascript_confirm
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to" data-remote="true"><input data-confirm="Are you sure?" type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", remote: true, data: { confirm: "Are you sure?" })
    )
  end

  def test_button_to_with_remote_and_javascript_disable_with
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to" data-remote="true"><input data-disable-with="Greeting..." type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", remote: true, data: { disable_with: "Greeting..." })
    )
  end

  def test_button_to_with_remote_false
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", remote: false)
    )
  end

  def test_button_to_enabled_disabled
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", disabled: false)
    )
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input disabled="disabled" type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", disabled: true)
    )
  end

  def test_button_to_with_method_delete
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><input type="hidden" name="_method" value="delete" /><input type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", method: :delete)
    )
  end

  def test_button_to_with_method_get
    assert_dom_equal(
      %{<form method="get" action="http://www.example.com" class="button_to"><input type="submit" value="Hello" /></form>},
      button_to("Hello", "http://www.example.com", method: :get)
    )
  end

  def test_button_to_with_block
    assert_dom_equal(
      %{<form method="post" action="http://www.example.com" class="button_to"><button type="submit"><span>Hello</span></button></form>},
      button_to("http://www.example.com") { content_tag(:span, 'Hello') }
    )
  end

  def test_button_to_with_params
    assert_dom_equal(
      %{<form action="http://www.example.com" class="button_to" method="post"><input type="submit" value="Hello" /><input type="hidden" name="foo" value="bar" /><input type="hidden" name="baz" value="quux" /></form>},
      button_to("Hello", "http://www.example.com", params: {foo: :bar, baz: "quux"})
    )
  end

  def test_link_tag_with_straight_url
    expected = %{<a href="http://www.example.com" title="Hello">Hello</a>}
    assert_dom_equal expected, link_to("Hello", "http://www.example.com")
  end

  def test_link_tag_with_custom_title
    expected = %{<a href="http://www.example.com" title="Hey you!">Hello</a>}
    assert_dom_equal expected, link_to("Hello", "http://www.example.com", title: 'Hey you!')
  end

  def test_link_tag_without_host_option
    expected = %{<a href="/" title="Test Link">Test Link</a>}
    assert_dom_equal(expected, link_to('Test Link', url_hash))
  end

  def test_link_tag_with_host_option
    hash = hash_for(host: "www.example.com")
    expected = %{<a href="http://www.example.com/" title="Test Link">Test Link</a>}
    assert_dom_equal(expected, link_to('Test Link', hash))
  end

  def test_link_tag_with_query
    expected = %{<a href="http://www.example.com?q1=v1&amp;q2=v2" title="Hello">Hello</a>}
    assert_dom_equal expected, link_to("Hello", "http://www.example.com?q1=v1&q2=v2")
  end

  def test_link_tag_with_query_and_no_name
    expected = %{<a href="http://www.example.com?q1=v1&amp;q2=v2">http://www.example.com?q1=v1&amp;q2=v2</a>}
    assert_dom_equal expected, link_to(nil, "http://www.example.com?q1=v1&q2=v2")
  end

  def test_link_tag_with_back
    env = {"HTTP_REFERER" => "http://www.example.com/referer"}
    @controller = Struct.new(:request).new(Struct.new(:env).new(env))
    expected = %{<a href="#{env["HTTP_REFERER"]}" title="go back">go back</a>}
    assert_dom_equal expected, link_to('go back', :back)
  end

  def test_link_tag_with_back_and_no_referer
    @controller = Struct.new(:request).new(Struct.new(:env).new({}))
    link = link_to('go back', :back)
    assert_dom_equal %{<a href="javascript:history.back()" title="go back">go back</a>}, link
  end

  def test_link_tag_with_img
    link = link_to("<img src='/favicon.jpg' />".html_safe, "/")
    expected = %{<a href="/"><img src='/favicon.jpg' /></a>}
    assert_dom_equal expected, link
  end

  def test_link_with_nil_html_options
    link = link_to("Hello", url_hash, nil)
    assert_dom_equal %{<a href="/" title="Hello">Hello</a>}, link
  end

  def test_link_tag_with_custom_onclick
    link = link_to("Hello", "http://www.example.com", onclick: "alert('yay!')")
    expected = %{<a onclick="alert(&#39;yay!&#39;)" href="http://www.example.com" title="Hello">Hello</a>}
    assert_dom_equal expected, link
  end

  def test_link_tag_with_javascript_confirm
    assert_dom_equal(
      %{<a data-confirm="Are you sure?" href="http://www.example.com" title="Hello">Hello</a>},
      link_to("Hello", "http://www.example.com", data: { confirm: "Are you sure?" })
    )
    assert_dom_equal(
      %{<a data-confirm="You cant possibly be sure, can you?" href="http://www.example.com" title="Hello">Hello</a>},
      link_to("Hello", "http://www.example.com", data: { confirm: "You cant possibly be sure, can you?" })
    )
    assert_dom_equal(
      %{<a data-confirm="You cant possibly be sure,\n can you?" href="http://www.example.com" title="Hello">Hello</a>},
      link_to("Hello", "http://www.example.com", data: { confirm: "You cant possibly be sure,\n can you?" })
    )
  end

  def test_link_to_with_remote
    assert_dom_equal(
      %{<a href="http://www.example.com" data-remote="true" title="Hello">Hello</a>},
      link_to("Hello", "http://www.example.com", remote: true)
    )
  end

  def test_link_to_with_remote_false
    assert_dom_equal(
      %{<a href="http://www.example.com" title="Hello">Hello</a>},
      link_to("Hello", "http://www.example.com", remote: false)
    )
  end

  def test_link_to_with_symbolic_remote_in_non_html_options
    assert_dom_equal(
      %{<a href="/" data-remote="true" title="Hello">Hello</a>},
      link_to("Hello", hash_for(remote: true), {})
    )
  end

  def test_link_to_with_string_remote_in_non_html_options
    assert_dom_equal(
      %{<a href="/" data-remote="true" title="Hello">Hello</a>},
      link_to("Hello", hash_for('remote' => true), {})
    )
  end

  def test_link_tag_using_post_javascript
    assert_dom_equal(
      %{<a href="http://www.example.com" data-method="post" rel="nofollow" title="Hello">Hello</a>},
      link_to("Hello", "http://www.example.com", method: :post)
    )
  end

  def test_link_tag_using_delete_javascript
    assert_dom_equal(
      %{<a href="http://www.example.com" rel="nofollow" data-method="delete" title="Destroy">Destroy</a>},
      link_to("Destroy", "http://www.example.com", method: :delete)
    )
  end

  def test_link_tag_using_delete_javascript_and_href
    assert_dom_equal(
      %{<a href="\#" rel="nofollow" data-method="delete" title="Destroy">Destroy</a>},
      link_to("Destroy", "http://www.example.com", method: :delete, href: '#')
    )
  end

  def test_link_tag_using_post_javascript_and_rel
    assert_dom_equal(
      %{<a href="http://www.example.com" data-method="post" rel="example nofollow" title="Hello">Hello</a>},
      link_to("Hello", "http://www.example.com", method: :post, rel: 'example')
    )
  end

  def test_link_tag_using_post_javascript_and_confirm
    assert_dom_equal(
      %{<a href="http://www.example.com" data-method="post" rel="nofollow" data-confirm="Are you serious?" title="Hello">Hello</a>},
      link_to("Hello", "http://www.example.com", method: :post, data: { confirm: "Are you serious?" })
    )
  end

  def test_link_tag_using_delete_javascript_and_href_and_confirm
    assert_dom_equal(
      %{<a href="\#" rel="nofollow" data-confirm="Are you serious?" data-method="delete" title="Destroy">Destroy</a>},
      link_to("Destroy", "http://www.example.com", method: :delete, href: '#', data: { confirm: "Are you serious?" })
    )
  end

  def test_link_tag_with_block
    assert_dom_equal %{<a href="/" title="Example site"><span>Example site</span></a>},
      link_to('/') { content_tag(:span, 'Example site') }
  end

  def test_link_tag_with_block_and_html_options
    assert_dom_equal %{<a class="special" href="/" title="Example site"><span>Example site</span></a>},
      link_to('/', class: "special") { content_tag(:span, 'Example site') }
  end

  def test_link_tag_using_block_and_hash
    assert_dom_equal(
      %{<a href="/" title="Example site"><span>Example site</span></a>},
      link_to(url_hash) { content_tag(:span, 'Example site') }
    )
  end

  def test_link_tag_using_block_in_erb
    out = render_erb %{<%= link_to('/') do %>Example site<% end %>}
    assert_equal '<a href="/" title="Example site">Example site</a>', out
  end

  def test_link_tag_with_html_safe_string
    assert_dom_equal(
      %{<a href="/article/Gerd_M%C3%BCller" title="Gerd Müller">Gerd Müller</a>},
      link_to("Gerd Müller", article_path("Gerd_Müller".html_safe))
    )
  end

  def test_link_tag_escapes_content
    assert_dom_equal %{<a href="/" title="Malicious ">Malicious &lt;script&gt;content&lt;/script&gt;</a>},
      link_to("Malicious <script>content</script>", "/")
  end

  def test_link_tag_does_not_escape_html_safe_content
    assert_dom_equal %{<a href="/" title="Malicious ">Malicious <script>content</script></a>},
      link_to("Malicious <script>content</script>".html_safe, "/")
  end

  def test_link_to_unless
    assert_equal "Showing", link_to_unless(true, "Showing", url_hash)

    assert_dom_equal %{<a href="/" title="Listing">Listing</a>},
      link_to_unless(false, "Listing", url_hash)

    assert_equal "<strong>Showing</strong>",
      link_to_unless(true, "Showing", url_hash) { |name|
        "<strong>#{name}</strong>".html_safe
      }

    assert_equal "test",
      link_to_unless(true, "Showing", url_hash) {
        "test"
      }

    assert_equal %{&lt;b&gt;Showing&lt;/b&gt;}, link_to_unless(true, "<b>Showing</b>", url_hash)
    assert_equal %{<a href="/" title="Showing">&lt;b&gt;Showing&lt;/b&gt;</a>}, link_to_unless(false, "<b>Showing</b>", url_hash)
    assert_equal %{<b>Showing</b>}, link_to_unless(true, "<b>Showing</b>".html_safe, url_hash)
    assert_equal %{<a href="/" title="Showing"><b>Showing</b></a>}, link_to_unless(false, "<b>Showing</b>".html_safe, url_hash)
  end

  def test_link_to_if
    assert_equal "Showing", link_to_if(false, "Showing", url_hash)
    assert_dom_equal %{<a href="/" title="Listing">Listing</a>}, link_to_if(true, "Listing", url_hash)
  end

  def test_link_to_if_with_block
    assert_equal "Fallback", link_to_if(false, "Showing", url_hash) { "Fallback" }
    assert_dom_equal %{<a href="/" title="Listing">Listing</a>}, link_to_if(true, "Listing", url_hash) { "Fallback" }
  end

  def request_for_url(url, opts = {})
    env = Rack::MockRequest.env_for("http://www.example.com#{url}", opts)
    ActionDispatch::Request.new(env)
  end

  def test_current_page_with_http_head_method
    @request = request_for_url("/", :method => :head)
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

  def test_current_page_with_params_that_match
    @request = request_for_url("/?order=desc&page=1")

    assert current_page?(hash_for(order: "desc", page: "1"))
    assert current_page?("http://www.example.com/?order=desc&page=1")
  end

  def test_current_page_with_not_get_verb
    @request = request_for_url("/events", method: :post)

    assert !current_page?('/events')
  end

  def test_current_page_with_escaped_params
    @request = request_for_url("/category/administra%c3%a7%c3%a3o")

    assert current_page?(controller: 'foo', action: 'category', category: 'administração')
  end

  def test_current_page_with_escaped_params_with_different_encoding
    @request = request_for_url("/")
    @request.stub(:path, "/category/administra%c3%a7%c3%a3o".force_encoding(Encoding::ASCII_8BIT)) do
      assert current_page?(:controller => 'foo', :action => 'category', category: 'administração')
      assert current_page?("http://www.example.com/category/administra%c3%a7%c3%a3o")
    end
  end

  def test_current_page_with_double_escaped_params
    @request = request_for_url("/category/administra%c3%a7%c3%a3o?callback_url=http%3a%2f%2fexample.com%2ffoo")

    assert current_page?(controller: 'foo', action: 'category', category: 'administração', callback_url: 'http://example.com/foo')
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
      link_to_unless_current("Showing", hash_for(order: 'desc', page: '1'))
    assert_equal "Showing",
      link_to_unless_current("Showing", "http://www.example.com/?order=desc&page=1")

    @request = request_for_url("/?order=desc")

    assert_equal %{<a href="/?order=asc" title="Showing">Showing</a>},
      link_to_unless_current("Showing", hash_for(order: :asc))
    assert_equal %{<a href="http://www.example.com/?order=asc" title="Showing">Showing</a>},
      link_to_unless_current("Showing", "http://www.example.com/?order=asc")

    @request = request_for_url("/?order=desc")
    assert_equal %{<a href="/?order=desc&amp;page=2\" title="Showing">Showing</a>},
      link_to_unless_current("Showing", hash_for(order: "desc", page: 2))
    assert_equal %{<a href="http://www.example.com/?order=desc&amp;page=2" title="Showing">Showing</a>},
      link_to_unless_current("Showing", "http://www.example.com/?order=desc&page=2")

    @request = request_for_url("/show")

    assert_equal %{<a href="/" title="Listing">Listing</a>},
      link_to_unless_current("Listing", url_hash)
    assert_equal %{<a href="http://www.example.com/" title="Listing">Listing</a>},
      link_to_unless_current("Listing", "http://www.example.com/")
  end

  def test_link_to_unless_with_block
    assert_dom_equal %{<a href="/" title="Showing">Showing</a>}, link_to_unless(false, "Showing", url_hash) { "Fallback" }
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

  def test_mail_with_options
    assert_dom_equal(
      %{<a href="mailto:me@example.com?cc=ccaddress%40example.com&amp;bcc=bccaddress%40example.com&amp;body=This%20is%20the%20body%20of%20the%20message.&amp;subject=This%20is%20an%20example%20email&amp;reply-to=foo%40bar.com">My email</a>},
      mail_to("me@example.com", "My email", cc: "ccaddress@example.com", bcc: "bccaddress@example.com", subject: "This is an example email", body: "This is the body of the message.", reply_to: "foo@bar.com")
    )

    assert_dom_equal(
      %{<a href="mailto:me@example.com?body=This%20is%20the%20body%20of%20the%20message.&amp;subject=This%20is%20an%20example%20email">My email</a>},
      mail_to("me@example.com", "My email", cc: '', bcc: '', subject: "This is an example email", body: "This is the body of the message.")
    )
  end

  def test_mail_to_with_img
    assert_dom_equal %{<a href="mailto:feedback@example.com"><img src="/feedback.png" /></a>},
      mail_to('feedback@example.com', '<img src="/feedback.png" />'.html_safe)
  end

  def test_mail_to_returns_html_safe_string
    assert mail_to("david@loudthinking.com").html_safe?
  end

  def test_mail_to_with_block
    assert_dom_equal %{<a href="mailto:me@example.com"><span>Email me</span></a>},
      mail_to('me@example.com') { content_tag(:span, 'Email me') }
  end

  def test_mail_to_with_block_and_options
    assert_dom_equal %{<a class="special" href="mailto:me@example.com?cc=ccaddress%40example.com"><span>Email me</span></a>},
      mail_to('me@example.com', cc: "ccaddress@example.com", class: "special") { content_tag(:span, 'Email me') }
  end

  def test_mail_to_does_not_modify_html_options_hash
    options = { class: 'special' }
    mail_to 'me@example.com', 'ME!', options
    assert_equal({ class: 'special' }, options)
  end

  def protect_against_forgery?
    self.request_forgery
  end

  def form_authenticity_token
    "secret"
  end

  def request_forgery_protection_token
    "form_token"
  end

  private
    def sort_query_string_params(uri)
      path, qs = uri.split('?')
      qs = qs.split('&amp;').sort.join('&amp;') if qs
      qs ? "#{path}?#{qs}" : path
    end
end

class UrlHelperControllerTest < ActionController::TestCase
  class UrlHelperController < ActionController::Base
    test_routes do
      get 'url_helper_controller_test/url_helper/show/:id',
        to: 'url_helper_controller_test/url_helper#show',
        as: :show

      get 'url_helper_controller_test/url_helper/profile/:name',
        to: 'url_helper_controller_test/url_helper#show',
        as: :profile

      get 'url_helper_controller_test/url_helper/show_named_route',
        to: 'url_helper_controller_test/url_helper#show_named_route',
        as: :show_named_route

      get "/:controller(/:action(/:id))"

      get 'url_helper_controller_test/url_helper/normalize_recall_params',
        to: UrlHelperController.action(:normalize_recall),
        as: :normalize_recall_params

      get '/url_helper_controller_test/url_helper/override_url_helper/default',
        to: 'url_helper_controller_test/url_helper#override_url_helper',
        as: :override_url_helper
    end

    def show
      if params[:name]
        render inline: 'ok'
      else
        redirect_to profile_path(params[:id])
      end
    end

    def show_url_for
      render inline: "<%= url_for controller: 'url_helper_controller_test/url_helper', action: 'show_url_for' %>"
    end

    def show_overridden_url_for
      render inline: "<%= url_for params.merge(controller: 'url_helper_controller_test/url_helper', action: 'show_url_for') %>"
    end

    def show_named_route
      render inline: "<%= show_named_route_#{params[:kind]} %>"
    end

    def nil_url_for
      render inline: '<%= url_for(nil) %>'
    end

    def normalize_recall_params
      render inline: '<%= normalize_recall_params_path %>'
    end

    def recall_params_not_changed
      render inline: '<%= url_for(action: :show_url_for) %>'
    end

    def override_url_helper
      render inline: '<%= override_url_helper_path %>'
    end

    def override_url_helper_path
      '/url_helper_controller_test/url_helper/override_url_helper/override'
    end
    helper_method :override_url_helper_path
  end

  tests UrlHelperController

  def test_url_for_shows_only_path
    get :show_url_for
    assert_equal '/url_helper_controller_test/url_helper/show_url_for', @response.body
  end

  def test_overridden_url_for_shows_only_path
    get :show_overridden_url_for
    assert_equal '/url_helper_controller_test/url_helper/show_url_for', @response.body
  end

  def test_named_route_url_shows_host_and_path
    get :show_named_route, params: { kind: 'url' }
    assert_equal 'http://test.host/url_helper_controller_test/url_helper/show_named_route',
      @response.body
  end

  def test_named_route_path_shows_only_path
    get :show_named_route, params: { kind: 'path' }
    assert_equal '/url_helper_controller_test/url_helper/show_named_route', @response.body
  end

  def test_url_for_nil_returns_current_path
    get :nil_url_for
    assert_equal '/url_helper_controller_test/url_helper/nil_url_for', @response.body
  end

  def test_named_route_should_show_host_and_path_using_controller_default_url_options
    class << @controller
      def default_url_options
        { host: 'testtwo.host' }
      end
    end

    get :show_named_route, params: { kind: 'url' }
    assert_equal 'http://testtwo.host/url_helper_controller_test/url_helper/show_named_route', @response.body
  end

  def test_recall_params_should_be_normalized
    get :normalize_recall_params
    assert_equal '/url_helper_controller_test/url_helper/normalize_recall_params', @response.body
  end

  def test_recall_params_should_not_be_changed
    get :recall_params_not_changed
    assert_equal '/url_helper_controller_test/url_helper/show_url_for', @response.body
  end

  def test_recall_params_should_normalize_id
    get :show, params: { id: '123' }
    assert_equal 302, @response.status
    assert_equal 'http://test.host/url_helper_controller_test/url_helper/profile/123', @response.location

    get :show, params: { name: '123' }
    assert_equal 'ok', @response.body
  end

  def test_url_helper_can_be_overridden
    get :override_url_helper
    assert_equal '/url_helper_controller_test/url_helper/override_url_helper/override', @response.body
  end
end

class TasksController < ActionController::Base
  test_routes do
    resources :tasks
  end

  def index
    render_default
  end

  def show
    render_default
  end

  protected
    def render_default
      render inline: "<%= link_to_unless_current('tasks', tasks_path) %>\n" +
        "<%= link_to_unless_current('tasks', tasks_url) %>"
    end
end

class LinkToUnlessCurrentWithControllerTest < ActionController::TestCase
  tests TasksController

  def test_link_to_unless_current_to_current
    get :index
    assert_equal "tasks\ntasks", @response.body
  end

  def test_link_to_unless_current_shows_link
    get :show, params: { id: 1 }
    assert_equal %{<a href="/tasks" title="tasks">tasks</a>\n} +
      %{<a href="#{@request.protocol}#{@request.host_with_port}/tasks" title="tasks">tasks</a>},
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
  test_routes do
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
end

class SessionsController < ActionController::Base
  test_routes do
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
end

class PolymorphicControllerTest < ActionController::TestCase
  def test_new_resource
    @controller = WorkshopsController.new

    get :index
    assert_equal %{/workshops\n<a href="/workshops" title="Workshop">Workshop</a>}, @response.body
  end

  def test_existing_resource
    @controller = WorkshopsController.new

    get :show, params: { id: 1 }
    assert_equal %{/workshops/1\n<a href="/workshops/1" title="Workshop">Workshop</a>}, @response.body
  end

  def test_new_nested_resource
    @controller = SessionsController.new

    get :index, params: { workshop_id: 1 }
    assert_equal %{/workshops/1/sessions\n<a href="/workshops/1/sessions" title="Session">Session</a>}, @response.body
  end

  def test_existing_nested_resource
    @controller = SessionsController.new

    get :show, params: { workshop_id: 1, id: 1 }
    assert_equal %{/workshops/1/sessions/1\n<a href="/workshops/1/sessions/1" title="Session">Session</a>}, @response.body
  end
end
