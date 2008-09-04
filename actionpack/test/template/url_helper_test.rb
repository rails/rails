# encoding: utf-8
require 'abstract_unit'

RequestMock = Struct.new("Request", :request_uri, :protocol, :host_with_port, :env)

class UrlHelperTest < ActionView::TestCase
  tests ActionView::Helpers::UrlHelper

  def setup
    @controller = Class.new do
      attr_accessor :url, :request
      def url_for(options)
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

  def test_url_for_escapes_url_once
    @controller.url = "http://www.example.com?a=b&amp;c=d"
    assert_equal "http://www.example.com?a=b&amp;c=d", url_for("http://www.example.com?a=b&amp;c=d")
  end

  def test_url_for_with_back
    @controller.request = RequestMock.new("http://www.example.com/weblog/show", nil, nil, {'HTTP_REFERER' => 'http://www.example.com/referer'})
    assert_equal 'http://www.example.com/referer', url_for(:back)
  end

  def test_url_for_with_back_and_no_referer
    @controller.request = RequestMock.new("http://www.example.com/weblog/show", nil, nil, {})
    assert_equal 'javascript:history.back()', url_for(:back)
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

  def test_link_tag_without_host_option
    ActionController::Base.class_eval { attr_accessor :url }
    url = {:controller => 'weblog', :action => 'show'}
    @controller = ActionController::Base.new
    @controller.request = ActionController::TestRequest.new
    @controller.url = ActionController::UrlRewriter.new(@controller.request, url)
    assert_dom_equal(%q{<a href="/weblog/show">Test Link</a>}, link_to('Test Link', url))
  end

  def test_link_tag_with_host_option
    ActionController::Base.class_eval { attr_accessor :url }
    url = {:controller => 'weblog', :action => 'show', :host => 'www.example.com'}
    @controller = ActionController::Base.new
    @controller.request = ActionController::TestRequest.new
    @controller.url = ActionController::UrlRewriter.new(@controller.request, url)
    assert_dom_equal(%q{<a href="http://www.example.com/weblog/show">Test Link</a>}, link_to('Test Link', url))
  end

  def test_link_tag_with_query
    assert_dom_equal "<a href=\"http://www.example.com?q1=v1&amp;q2=v2\">Hello</a>", link_to("Hello", "http://www.example.com?q1=v1&amp;q2=v2")
  end

  def test_link_tag_with_query_and_no_name
    assert_dom_equal "<a href=\"http://www.example.com?q1=v1&amp;q2=v2\">http://www.example.com?q1=v1&amp;q2=v2</a>", link_to(nil, "http://www.example.com?q1=v1&amp;q2=v2")
  end

  def test_link_tag_with_back
    @controller.request = RequestMock.new("http://www.example.com/weblog/show", nil, nil, {'HTTP_REFERER' => 'http://www.example.com/referer'})
    assert_dom_equal "<a href=\"http://www.example.com/referer\">go back</a>", link_to('go back', :back)
  end

  def test_link_tag_with_back_and_no_referer
    @controller.request = RequestMock.new("http://www.example.com/weblog/show", nil, nil, {})
    assert_dom_equal "<a href=\"javascript:history.back()\">go back</a>", link_to('go back', :back)
  end

  def test_link_tag_with_back
    @controller.request = RequestMock.new("http://www.example.com/weblog/show", nil, nil, {'HTTP_REFERER' => 'http://www.example.com/referer'})
    assert_dom_equal "<a href=\"http://www.example.com/referer\">go back</a>", link_to('go back', :back)
  end

  def test_link_tag_with_back_and_no_referer
    @controller.request = RequestMock.new("http://www.example.com/weblog/show", nil, nil, {})
    assert_dom_equal "<a href=\"javascript:history.back()\">go back</a>", link_to('go back', :back)
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

  def test_link_tag_using_delete_javascript_and_href
    assert_dom_equal(
      "<a href='\#' onclick=\"var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = 'http://www.example.com';var m = document.createElement('input'); m.setAttribute('type', 'hidden'); m.setAttribute('name', '_method'); m.setAttribute('value', 'delete'); f.appendChild(m);f.submit();return false;\">Destroy</a>",
      link_to("Destroy", "http://www.example.com", :method => :delete, :href => '#')
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

  def test_link_tag_using_block_in_erb
    __in_erb_template = ''

    link_to("http://example.com") { concat("Example site") }

    assert_equal '<a href="http://example.com">Example site</a>', output_buffer
  end

  def test_link_to_unless
    assert_equal "Showing", link_to_unless(true, "Showing", :action => "show", :controller => "weblog")
    assert_dom_equal "<a href=\"http://www.example.com\">Listing</a>", link_to_unless(false, "Listing", :action => "list", :controller => "weblog")
    assert_equal "Showing", link_to_unless(true, "Showing", :action => "show", :controller => "weblog", :id => 1)
    assert_equal "<strong>Showing</strong>", link_to_unless(true, "Showing", :action => "show", :controller => "weblog", :id => 1) { |name, options, html_options|
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
    assert_equal "Showing", link_to_unless_current("Showing", "http://www.example.com/weblog/show")

    @controller.request = RequestMock.new("http://www.example.com/weblog/show")
    @controller.url = "http://www.example.com/weblog/list"
    assert_equal "<a href=\"http://www.example.com/weblog/list\">Listing</a>",
      link_to_unless_current("Listing", :action => "list", :controller => "weblog")
    assert_equal "<a href=\"http://www.example.com/weblog/list\">Listing</a>",
      link_to_unless_current("Listing", "http://www.example.com/weblog/list")
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
    assert_dom_equal "<script type=\"text/javascript\">eval(decodeURIComponent('%64%6f%63%75%6d%65%6e%74%2e%77%72%69%74%65%28%27%3c%61%20%68%72%65%66%3d%22%6d%61%69%6c%74%6f%3a%6d%65%40%64%6f%6d%61%69%6e%2e%63%6f%6d%22%3e%4d%79%20%65%6d%61%69%6c%3c%2f%61%3e%27%29%3b'))</script>", mail_to("me@domain.com", "My email", :encode => "javascript")
  end

  def test_mail_to_with_javascript_unicode
    assert_dom_equal "<script type=\"text/javascript\">eval(decodeURIComponent('%64%6f%63%75%6d%65%6e%74%2e%77%72%69%74%65%28%27%3c%61%20%68%72%65%66%3d%22%6d%61%69%6c%74%6f%3a%75%6e%69%63%6f%64%65%40%65%78%61%6d%70%6c%65%2e%63%6f%6d%22%3e%c3%ba%6e%69%63%6f%64%65%3c%2f%61%3e%27%29%3b'))</script>", mail_to("unicode@example.com", "únicode", :encode => "javascript")
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
    assert_dom_equal "<a href=\"&#109;&#97;&#105;&#108;&#116;&#111;&#58;%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">My email</a>", mail_to("me@domain.com", "My email", :encode => "hex")
    assert_dom_equal "<a href=\"&#109;&#97;&#105;&#108;&#116;&#111;&#58;%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">&#109;&#101;&#64;&#100;&#111;&#109;&#97;&#105;&#110;&#46;&#99;&#111;&#109;</a>", mail_to("me@domain.com", nil, :encode => "hex")
  end

  def test_mail_to_with_replace_options
    assert_dom_equal "<a href=\"mailto:wolfgang@stufenlos.net\">wolfgang(at)stufenlos(dot)net</a>", mail_to("wolfgang@stufenlos.net", nil, :replace_at => "(at)", :replace_dot => "(dot)")
    assert_dom_equal "<a href=\"&#109;&#97;&#105;&#108;&#116;&#111;&#58;%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">&#109;&#101;&#40;&#97;&#116;&#41;&#100;&#111;&#109;&#97;&#105;&#110;&#46;&#99;&#111;&#109;</a>", mail_to("me@domain.com", nil, :encode => "hex", :replace_at => "(at)")
    assert_dom_equal "<a href=\"&#109;&#97;&#105;&#108;&#116;&#111;&#58;%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">My email</a>", mail_to("me@domain.com", "My email", :encode => "hex", :replace_at => "(at)")
    assert_dom_equal "<a href=\"&#109;&#97;&#105;&#108;&#116;&#111;&#58;%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d\">&#109;&#101;&#40;&#97;&#116;&#41;&#100;&#111;&#109;&#97;&#105;&#110;&#40;&#100;&#111;&#116;&#41;&#99;&#111;&#109;</a>", mail_to("me@domain.com", nil, :encode => "hex", :replace_at => "(at)", :replace_dot => "(dot)")
    assert_dom_equal "<script type=\"text/javascript\">eval(decodeURIComponent('%64%6f%63%75%6d%65%6e%74%2e%77%72%69%74%65%28%27%3c%61%20%68%72%65%66%3d%22%6d%61%69%6c%74%6f%3a%6d%65%40%64%6f%6d%61%69%6e%2e%63%6f%6d%22%3e%4d%79%20%65%6d%61%69%6c%3c%2f%61%3e%27%29%3b'))</script>", mail_to("me@domain.com", "My email", :encode => "javascript", :replace_at => "(at)", :replace_dot => "(dot)")
    assert_dom_equal "<script type=\"text/javascript\">eval(decodeURIComponent('%64%6f%63%75%6d%65%6e%74%2e%77%72%69%74%65%28%27%3c%61%20%68%72%65%66%3d%22%6d%61%69%6c%74%6f%3a%6d%65%40%64%6f%6d%61%69%6e%2e%63%6f%6d%22%3e%6d%65%28%61%74%29%64%6f%6d%61%69%6e%28%64%6f%74%29%63%6f%6d%3c%2f%61%3e%27%29%3b'))</script>", mail_to("me@domain.com", nil, :encode => "javascript", :replace_at => "(at)", :replace_dot => "(dot)")
  end

  def protect_against_forgery?
    false
  end
end

class UrlHelperWithControllerTest < ActionView::TestCase
  class UrlHelperController < ActionController::Base
    def self.controller_path; 'url_helper_with_controller' end

    def show_url_for
      render :inline => "<%= url_for :controller => 'url_helper_with_controller', :action => 'show_url_for' %>"
    end

    def show_named_route
      render :inline => "<%= show_named_route_#{params[:kind]} %>"
    end

    def nil_url_for
      render :inline => '<%= url_for(nil) %>'
    end

    def rescue_action(e) raise e end
  end

  tests ActionView::Helpers::UrlHelper

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = UrlHelperController.new
  end

  def test_url_for_shows_only_path
    get :show_url_for
    assert_equal '/url_helper_with_controller/show_url_for', @response.body
  end

  def test_named_route_url_shows_host_and_path
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

  def test_url_for_nil_returns_current_path
    get :nil_url_for
    assert_equal '/url_helper_with_controller/nil_url_for', @response.body
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

class LinkToUnlessCurrentWithControllerTest < ActionView::TestCase
  class TasksController < ActionController::Base
    def self.controller_path; 'tasks' end

    def index
      render_default
    end

    def show
      render_default
    end

    def rescue_action(e) raise e end

    protected
      def render_default
        render :inline =>
          "<%= link_to_unless_current(\"tasks\", tasks_path) %>\n" +
          "<%= link_to_unless_current(\"tasks\", tasks_url) %>"
      end
  end

  tests ActionView::Helpers::UrlHelper

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = TasksController.new
  end

  def test_link_to_unless_current_to_current
    with_restful_routing do
      get :index
      assert_equal "tasks\ntasks", @response.body
    end
  end

  def test_link_to_unless_current_shows_link
    with_restful_routing do
      get :show, :id => 1
      assert_equal "<a href=\"/tasks\">tasks</a>\n" +
        "<a href=\"#{@request.protocol}#{@request.host_with_port}/tasks\">tasks</a>",
        @response.body
    end
  end

  protected
    def with_restful_routing
      with_routing do |set|
        set.draw do |map|
          map.resources :tasks
        end
        yield
      end
    end
end

class Workshop
  attr_accessor :id, :new_record

  def initialize(id, new_record)
    @id, @new_record = id, new_record
  end

  def new_record?
    @new_record
  end

  def to_s
    id.to_s
  end
end

class Session
  attr_accessor :id, :workshop_id, :new_record

  def initialize(id, new_record)
    @id, @new_record = id, new_record
  end

  def new_record?
    @new_record
  end

  def to_s
    id.to_s
  end
end

class PolymorphicControllerTest < ActionView::TestCase
  class WorkshopsController < ActionController::Base
    def self.controller_path; 'workshops' end

    def index
      @workshop = Workshop.new(1, true)
      render :inline => "<%= url_for(@workshop) %>\n<%= link_to('Workshop', @workshop) %>"
    end

    def show
      @workshop = Workshop.new(params[:id], false)
      render :inline => "<%= url_for(@workshop) %>\n<%= link_to('Workshop', @workshop) %>"
    end

    def rescue_action(e) raise e end
  end

  class SessionsController < ActionController::Base
    def self.controller_path; 'sessions' end

    def index
      @workshop = Workshop.new(params[:workshop_id], false)
      @session = Session.new(1, true)
      render :inline => "<%= url_for([@workshop, @session]) %>\n<%= link_to('Session', [@workshop, @session]) %>"
    end

    def show
      @workshop = Workshop.new(params[:workshop_id], false)
      @session = Session.new(params[:id], false)
      render :inline => "<%= url_for([@workshop, @session]) %>\n<%= link_to('Session', [@workshop, @session]) %>"
    end

    def rescue_action(e) raise e end
  end

  tests ActionView::Helpers::UrlHelper

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_new_resource
    @controller = WorkshopsController.new

    with_restful_routing do
      get :index
      assert_equal "/workshops\n<a href=\"/workshops\">Workshop</a>", @response.body
    end
  end

  def test_existing_resource
    @controller = WorkshopsController.new

    with_restful_routing do
      get :show, :id => 1
      assert_equal "/workshops/1\n<a href=\"/workshops/1\">Workshop</a>", @response.body
    end
  end

  def test_new_nested_resource
    @controller = SessionsController.new

    with_restful_routing do
      get :index, :workshop_id => 1
      assert_equal "/workshops/1/sessions\n<a href=\"/workshops/1/sessions\">Session</a>", @response.body
    end
  end

  def test_existing_nested_resource
    @controller = SessionsController.new

    with_restful_routing do
      get :show, :workshop_id => 1, :id => 1
      assert_equal "/workshops/1/sessions/1\n<a href=\"/workshops/1/sessions/1\">Session</a>", @response.body
    end
  end

  protected
    def with_restful_routing
      with_routing do |set|
        set.draw do |map|
          map.resources :workshops do |w|
            w.resources :sessions
          end
        end
        yield
      end
    end
end
