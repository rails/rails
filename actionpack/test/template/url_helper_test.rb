require File.dirname(__FILE__) + '/../abstract_unit'

require File.dirname(__FILE__) + '/../../lib/action_view/helpers/url_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/asset_tag_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/tag_helper'

RequestMock = Struct.new("Request", :request_uri)

class UrlHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper

  def setup
    @controller = Class.new do
      attr_accessor :url, :request
      def url_for(options, *parameters_for_method_reference)
        url
      end
    end
    @controller = @controller.new
    @controller.url = "http://www.example.com"
  end
  
  def test_url_for_escapes_urls
    @controller.url = "http://www.example.com?a=b&c=d"
    assert_equal "http://www.example.com?a=b&amp;c=d", url_for(:a => 'b', :c => 'd')
    assert_equal "http://www.example.com?a=b&amp;c=d", url_for(:a => 'b', :c => 'd', :escape => true)
    assert_equal "http://www.example.com?a=b&c=d", url_for(:a => 'b', :c => 'd', :escape => false)
  end

  # todo: missing test cases
  def test_button_to_with_straight_url
    assert_dom_equal "<form method=\"post\" action=\"http://www.example.com\" class=\"button-to\"><div><input type=\"submit\" value=\"Hello\" /></div></form>", button_to("Hello", "http://www.example.com")
  end

  def test_button_to_with_query
    assert_dom_equal "<form method=\"post\" action=\"http://www.example.com/q1=v1&amp;q2=v2\" class=\"button-to\"><div><input type=\"submit\" value=\"Hello\" /></div></form>", button_to("Hello", "http://www.example.com/q1=v1&q2=v2")
  end

  def test_button_to_with_escaped_query
    assert_dom_equal "<form method=\"post\" action=\"http://www.example.com/q1=v1&amp;q2=v2\" class=\"button-to\"><div><input type=\"submit\" value=\"Hello\" /></div></form>", button_to("Hello", "http://www.example.com/q1=v1&amp;q2=v2")
  end

  def test_button_to_with_query_and_no_name
    assert_dom_equal "<form method=\"post\" action=\"http://www.example.com?q1=v1&amp;q2=v2\" class=\"button-to\"><div><input type=\"submit\" value=\"http://www.example.com?q1=v1&amp;q2=v2\" /></div></form>", button_to(nil, "http://www.example.com?q1=v1&q2=v2")
  end

  def test_button_to_with_javascript_confirm
    assert_dom_equal(
      "<form method=\"post\" action=\"http://www.example.com\" class=\"button-to\"><div><input onclick=\"return confirm('Are you sure?');\" type=\"submit\" value=\"Hello\" /></div></form>",
      button_to("Hello", "http://www.example.com", :confirm => "Are you sure?")
    )
  end

  def test_button_to_enabled_disabled
    assert_dom_equal(
      "<form method=\"post\" action=\"http://www.example.com\" class=\"button-to\"><div><input type=\"submit\" value=\"Hello\" /></div></form>",
      button_to("Hello", "http://www.example.com", :disabled => false)
    )
    assert_dom_equal(
      "<form method=\"post\" action=\"http://www.example.com\" class=\"button-to\"><div><input disabled=\"disabled\" type=\"submit\" value=\"Hello\" /></div></form>",
      button_to("Hello", "http://www.example.com", :disabled => true)
    )
  end
  
  def test_button_to_with_method_delete
    assert_dom_equal(
      "<form method=\"post\" action=\"http://www.example.com\" class=\"button-to\"><div><input type=\"hidden\" name=\"_method\" value=\"delete\" /><input type=\"submit\" value=\"Hello\" /></div></form>",
      button_to("Hello", "http://www.example.com", :method => :delete)
    )
  end
  
  def test_button_to_with_method_get
    assert_dom_equal(
      "<form method=\"get\" action=\"http://www.example.com\" class=\"button-to\"><div><input type=\"submit\" value=\"Hello\" /></div></form>",
      button_to("Hello", "http://www.example.com", :method => :get)
    )
  end

  def test_link_tag_with_straight_url
    assert_dom_equal "<a href=\"http://www.example.com\">Hello</a>", link_to("Hello", "http://www.example.com")
  end

  def test_link_tag_with_query
    assert_dom_equal "<a href=\"http://www.example.com?q1=v1&amp;q2=v2\">Hello</a>", link_to("Hello", "http://www.example.com?q1=v1&amp;q2=v2")
  end

  def test_link_tag_with_query_and_no_name
    assert_dom_equal "<a href=\"http://www.example.com?q1=v1&amp;q2=v2\">http://www.example.com?q1=v1&amp;q2=v2</a>", link_to(nil, "http://www.example.com?q1=v1&amp;q2=v2")
  end

  def test_link_tag_with_img
    assert_dom_equal "<a href=\"http://www.example.com\"><img src='/favicon.jpg' /></a>", link_to("<img src='/favicon.jpg' />", "http://www.example.com")
  end

  def test_link_with_nil_html_options
    assert_dom_equal "<a href=\"http://www.example.com\">Hello</a>", link_to("Hello", {:action => 'myaction'}, nil)
  end

  def test_link_tag_with_custom_onclick
    assert_dom_equal "<a href=\"http://www.example.com\" onclick=\"alert('yay!')\">Hello</a>", link_to("Hello", "http://www.example.com", :onclick => "alert('yay!')")
  end
  
  def test_link_tag_with_javascript_confirm
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"return confirm('Are you sure?');\">Hello</a>",
      link_to("Hello", "http://www.example.com", :confirm => "Are you sure?")
    )
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"return confirm('You can\\'t possibly be sure, can you?');\">Hello</a>", 
      link_to("Hello", "http://www.example.com", :confirm => "You can't possibly be sure, can you?")
    )
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"return confirm('You can\\'t possibly be sure,\\n can you?');\">Hello</a>", 
      link_to("Hello", "http://www.example.com", :confirm => "You can't possibly be sure,\n can you?")
    )
  end

  def test_link_tag_with_popup
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"window.open(this.href);return false;\">Hello</a>",
      link_to("Hello", "http://www.example.com", :popup => true)
    )
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"window.open(this.href);return false;\">Hello</a>", 
      link_to("Hello", "http://www.example.com", :popup => 'true')
    )
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"window.open(this.href,'window_name','width=300,height=300');return false;\">Hello</a>", 
      link_to("Hello", "http://www.example.com", :popup => ['window_name', 'width=300,height=300'])
    )
  end
  
  def test_link_tag_with_popup_and_javascript_confirm
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"if (confirm('Fo\\' sho\\'?')) { window.open(this.href); };return false;\">Hello</a>",
      link_to("Hello", "http://www.example.com", { :popup => true, :confirm => "Fo' sho'?" })
    )
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"if (confirm('Are you serious?')) { window.open(this.href,'window_name','width=300,height=300'); };return false;\">Hello</a>",
      link_to("Hello", "http://www.example.com", { :popup => ['window_name', 'width=300,height=300'], :confirm => "Are you serious?" })
    )
  end
  
  def test_link_tag_with_post_is_deprecated
    assert_deprecated 'post' do
      assert_dom_equal(
        "<a href='http://www.example.com' onclick=\"var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href;f.submit();return false;\">Hello</a>",
        link_to("Hello", "http://www.example.com", :post => true)
      )
    end
  end
  
  def test_link_tag_using_post_javascript
    assert_dom_equal(
      "<a href='http://www.example.com' onclick=\"var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href;f.submit();return false;\">Hello</a>",
      link_to("Hello", "http://www.example.com", :method => :post)
    )
  end

  def test_link_tag_using_delete_javascript
    assert_dom_equal(
      "<a href='http://www.example.com' onclick=\"var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href;var m = document.createElement('input'); m.setAttribute('type', 'hidden'); m.setAttribute('name', '_method'); m.setAttribute('value', 'delete'); f.appendChild(m);f.submit();return false;\">Destroy</a>",
      link_to("Destroy", "http://www.example.com", :method => :delete)
    )
  end
  
  def test_link_tag_using_post_javascript_and_confirm
    assert_dom_equal(
      "<a href=\"http://www.example.com\" onclick=\"if (confirm('Are you serious?')) { var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href;f.submit(); };return false;\">Hello</a>",
      link_to("Hello", "http://www.example.com", :method => :post, :confirm => "Are you serious?")
    )    
  end
  
  def test_link_tag_using_post_javascript_and_popup
    assert_raises(ActionView::ActionViewError) { link_to("Hello", "http://www.example.com", :popup => true, :method => :post, :confirm => "Are you serious?") }
  end
  
  def test_link_to_unless
    assert_equal "Showing", link_to_unless(true, "Showing", :action => "show", :controller => "weblog")
    assert_dom_equal "<a href=\"http://www.example.com\">Listing</a>", link_to_unless(false, "Listing", :action => "list", :controller => "weblog")
    assert_equal "Showing", link_to_unless(true, "Showing", :action => "show", :controller => "weblog", :id => 1)
    assert_equal "<strong>Showing</strong>", link_to_unless(true, "Showing", :action => "show", :controller => "weblog", :id => 1) { |name, options, html_options, *parameters_for_method_reference|
      "<strong>#{name}</strong>"
    }
    assert_equal "<strong>Showing</strong>", link_to_unless(true, "Showing", :action => "show", :controller => "weblog", :id => 1) { |name|
      "<strong>#{name}</strong>"
    }    
    assert_equal "test", link_to_unless(true, "Showing", :action => "show", :controller => "weblog", :id => 1) {
      "test"
    }    
  end
  
  def test_link_to_if
    assert_equal "Showing", link_to_if(false, "Showing", :action => "show", :controller => "weblog")
    assert_dom_equal "<a href=\"http://www.example.com\">Listing</a>", link_to_if(true, "Listing", :action => "list", :controller => "weblog")
    assert_equal "Showing", link_to_if(false, "Showing", :action => "show", :controller => "weblog", :id => 1)
  end

  def test_link_unless_current
    @controller.request = RequestMock.new("http://www.example.com/weblog/show")
    @controller.url = "http://www.example.com/weblog/show"
    assert_equal "Showing", link_to_unless_current("Showing", { :action => "show", :controller => "weblog" })

    @controller.request = RequestMock.new("http://www.example.com/weblog/show")
    @controller.url = "http://www.example.com/weblog/list"
    assert_equal "<a href=\"http://www.example.com/weblog/list\">Listing</a>", link_to_unless_current("Listing", :action => "list", :controller => "weblog")
  end
  
  def test_mail_to
    assert_dom_equal "<a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>", mail_to("david@loudthinking.com")
    assert_dom_equal "<a href=\"mailto:david@loudthinking.com\">David Heinemeier Hansson</a>", mail_to("david@loudthinking.com", "David Heinemeier Hansson")
    assert_dom_equal(
      "<a class=\"admin\" href=\"mailto:david@loudthinking.com\">David Heinemeier Hansson</a>",
      mail_to("david@loudthinking.com", "David Heinemeier Hansson", "class" => "admin")
    )
    assert_equal mail_to("david@loudthinking.com", "David Heinemeier Hansson", "class" => "admin"),
                 mail_to("david@loudthinking.com", "David Heinemeier Hansson", :class => "admin")
  end

  def test_mail_to_with_javascript
    assert_dom_equal "<script type=\"text/javascript\">eval(unescape('%64%6f%63%75%6d%65%6e%74%2e%77%72%69%74%65%28%27%3c%61%20%68%72%65%66%3d%22%6d%61%69%6c%74%6f%3a%6d%65%40%64%6f%6d%61%69%6e%2e%63%6f%6d%22%3e%4d%79%20%65%6d%61%69%6c%3c%2f%61%3e%27%29%3b'))</script>", mail_to("me@domain.com", "My email", :encode => "javascript")
  end
  
  def test_mail_with_options
    assert_dom_equal(
      %(<a href="mailto:me@example.com?cc=ccaddress%40example.com&amp;bcc=bccaddress%40example.com&amp;body=This%20is%20the%20body%20of%20the%20message.&amp;subject=This%20is%20an%20example%20email">My email</a>),
      mail_to("me@example.com", "My email", :cc => "ccaddress@example.com", :bcc => "bccaddress@example.com", :subject => "This is an example email", :body => "This is the body of the message.")
    )
  end
  
  def test_mail_to_with_img
    assert_dom_equal %(<a href="mailto:feedback@example.com"><img src="/feedback.png" /></a>), mail_to('feedback@example.com', '<img src="/feedback.png" />')
  end

  def test_mail_to_with_hex
    assert_dom_equal "<a href=\"mailto:%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">My email</a>", mail_to("me@domain.com", "My email", :encode => "hex")
  end

  def test_mail_to_with_replace_options
    assert_dom_equal "<a href=\"mailto:wolfgang@stufenlos.net\">wolfgang(at)stufenlos(dot)net</a>", mail_to("wolfgang@stufenlos.net", nil, :replace_at => "(at)", :replace_dot => "(dot)")
    assert_dom_equal "<a href=\"mailto:%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">me(at)domain.com</a>", mail_to("me@domain.com", nil, :encode => "hex", :replace_at => "(at)")
    assert_dom_equal "<a href=\"mailto:%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">My email</a>", mail_to("me@domain.com", "My email", :encode => "hex", :replace_at => "(at)")
    assert_dom_equal "<a href=\"mailto:%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">me(at)domain(dot)com</a>", mail_to("me@domain.com", nil, :encode => "hex", :replace_at => "(at)", :replace_dot => "(dot)")
    assert_dom_equal "<script type=\"text/javascript\">eval(unescape('%64%6f%63%75%6d%65%6e%74%2e%77%72%69%74%65%28%27%3c%61%20%68%72%65%66%3d%22%6d%61%69%6c%74%6f%3a%6d%65%40%64%6f%6d%61%69%6e%2e%63%6f%6d%22%3e%4d%79%20%65%6d%61%69%6c%3c%2f%61%3e%27%29%3b'))</script>", mail_to("me@domain.com", "My email", :encode => "javascript", :replace_at => "(at)", :replace_dot => "(dot)")
  end
end

class UrlHelperWithControllerTest < Test::Unit::TestCase
  class UrlHelperController < ActionController::Base
    self.template_root = "#{File.dirname(__FILE__)}/../fixtures/"

    def self.controller_path; 'url_helper_with_controller' end

    def show_url_for
      render :inline => "<%= url_for :controller => 'url_helper_with_controller', :action => 'show_url_for' %>"
    end
    
    def show_named_route
      render :inline => "<%= show_named_route_#{params[:kind]} %>"
    end

    def rescue_action(e) raise e end
  end

  include ActionView::Helpers::UrlHelper

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = UrlHelperController.new
  end
  
  def test_url_for_shows_only_path
    get :show_url_for
    assert_equal '/url_helper_with_controller/show_url_for', @response.body
  end
  
  def test_named_route_shows_host_and_path
    with_url_helper_routing do
      get :show_named_route, :kind => 'url'
      assert_equal 'http://test.host/url_helper_with_controller/show_named_route', @response.body
    end
  end
  
  def test_named_route_path_shows_only_path
    with_url_helper_routing do
      get :show_named_route, :kind => 'path'
      assert_equal '/url_helper_with_controller/show_named_route', @response.body
    end
  end
  
  protected
    def with_url_helper_routing
      with_routing do |set|
        set.draw do |map|
          map.show_named_route 'url_helper_with_controller/show_named_route', :controller => 'url_helper_with_controller', :action => 'show_named_route'
        end
        yield
      end
    end
end
