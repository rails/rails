require "abstract_unit"

class AjaxTestCase < ActionView::TestCase
  include ActionView::Helpers::AjaxHelper

  def url_for(options)
    case options
      when Hash
        "/url/hash"
      when String
        options
      else
        raise TypeError.new("Unsupported url type (#{options.class}) for this test helper")
    end
  end

  def assert_html(html, matches)
    matches.each do |match|
      assert_match Regexp.new(Regexp.escape(match)), html
    end
  end

  def assert_html_not_present(html, matches)
    matches.each do |match|
      assert_no_match Regexp.new(Regexp.escape(match)), html
    end
  end

  def self.assert_callbacks_work(&blk)
    define_method(:assert_callbacks_work, &blk)

    [:complete, :failure, :success, :interactive, :loaded, :loading, 404].each do |callback|
      test "#{callback} callback" do
        markup = assert_callbacks_work(callback)
        assert_html markup, %W(data-#{callback}-code="undoRequestCompleted\(request\)")
      end
    end
  end
end

class LinkToRemoteTest < AjaxTestCase
  def url_for(hash)
    "/blog/destroy/4"
  end

  def link(options = {})
    link_to_remote("Delete this post", "/blog/destroy/4", options)
  end

  test "with no update" do
    assert_html link, %w(href="/blog/destroy/4" Delete\ this\ post data-remote="true")
  end

  test "basic" do
    assert_html link(:update => "#posts"),
      %w(data-update-success="#posts")
  end

  test "using a url hash" do
    link = link_to_remote("Delete this post", {:controller => :blog}, :update => "#posts")
    assert_html link, %w(href="/url/hash" data-update-success="#posts")
  end

  test "with no update" do
    assert_html link, %w(href="/blog/destroy/4" Delete\ this\ post data-js-type="remote")
  end

  test "with :html options" do
    expected = %{<a href="/blog/destroy/4" data-custom="me" data-js-type="remote" data-update-success="#posts">Delete this post</a>}
    assert_equal expected, link(:update => "#posts", :html => {"data-custom" => "me"})
  end

  test "with a hash for :update" do
    link = link(:update => {:success => "#posts", :failure => "#error"})
    assert_html link, %w(data-js-type="remote" data-update-success="#posts" data-update-failure="#error")
  end

  test "with positional parameters" do
    link = link(:position => :top, :update => "#posts")
    assert_match /data\-update\-position="top"/, link
  end

  test "with an optional method" do
    link = link(:method => "delete")
    assert_match /data-method="delete"/, link
  end

  class LegacyLinkToRemoteTest < AjaxTestCase
    include ActionView::Helpers::AjaxHelper::Rails2Compatibility

    def link(options)
      link_to_remote("Delete this post", "/blog/destroy/4", options)
    end

    test "basic link_to_remote with :url =>" do
      expected = %{<a href="/blog/destroy/4" data-js-type="remote" data-update-success="#posts">Delete this post</a>}
      assert_equal expected,
        link_to_remote("Delete this post", :url => "/blog/destroy/4", :update => "#posts")
    end

    assert_callbacks_work do |callback|
      link(callback => "undoRequestCompleted(request)")
    end
  end
end

class FormRemoteTagTest < AjaxTestCase

  def protect_against_forgery?
    false
  end

  def request_forgery_protection_token
    "token_name"
  end

  def form_authenticity_token
    "t0k3n"
  end

  def authenticity_input_attributes
    %w(input type="hidden" name="token_name" value="t0k3n")
  end

  # TODO: Play with using assert_dom_equal
  test "basic" do
    assert_dom_equal %(<form action="/url/hash" method="post" data-js-type="remote" data-update-success="#glass_of_beer">),
      form_remote_tag(:update => "#glass_of_beer", :url => { :action => :fast  })
  end

  test "when protect_against_forgery? is true" do
    def protect_against_forgery?
      true
    end

    expected_form_attributes = %w(form action="/url/hash" method="post" data-js-type="remote" data-update-success="#glass_of_beer")
    expected_patterns = expected_form_attributes + authenticity_input_attributes

    assert_equal true, protect_against_forgery?    
    assert_html form_remote_tag(:update => "#glass_of_beer", :url => { :action => :fast  }), expected_patterns
  end

  test ":action is used when it is present" do
    html = form_remote_tag(:update => "#glass_of_beer", :action => "foo")

    assert_html html, %w(form action="foo" method="post" data-js-type="remote" data-update-success="#glass_of_beer")
    assert_no_match /url="foo"/, html
  end

  test ":url is used when :action is not present" do
    html = form_remote_tag(:update => "#glass_of_beer", :url => "bar")

    assert_html html, %w(form action="bar" method="post" data-js-type="remote" data-update-success="#glass_of_beer")
    assert_no_match /url="bar"/, html
  end

  test "when protect_against_forgery? is false" do
    assert_equal false, protect_against_forgery?
    assert_html_not_present form_remote_tag(:update => "#glass_of_beer", :url => { :action => :fast  }),
      authenticity_input_attributes
  end

  test "update callbacks" do
    assert_html form_remote_tag(:update => { :success => "#glass_of_beer" }, :url => { :action => :fast  }),
      %w(form action="/url/hash" method="post" data-js-type="remote" data-update-success="#glass_of_beer")

    assert_html form_remote_tag(:update => { :failure => "#glass_of_water" }, :url => { :action => :fast  }),
      %w(form action="/url/hash" method="post" data-js-type="remote" data-update-failure="#glass_of_water")

    assert_html form_remote_tag(:update => { :success => "#glass_of_beer", :failure => "#glass_of_water" }, :url => { :action => :fast  }),
      %w(form action="/url/hash" method="post" data-js-type="remote" data-update-success="#glass_of_beer" data-update-failure="#glass_of_water")
  end

  test "using a :method option" do
    expected_form_attributes = %w(form action="/url/hash" method="post" data-js-type="remote" data-update-success="#glass_of_beer")
    # TODO: Experiment with not using this _method param.  Apparently this is done to address browser incompatibilities, but since
    # we have a layer between the HTML and the JS libs now, we can probably get away with letting JS the JS libs handle the requirement
    # for an extra field if needed.
    expected_input_attributes = %w(input name="_method" type="hidden" value="put")

    assert_html form_remote_tag(:update => "#glass_of_beer", :url => { :action => :fast  }, :html => { :method => :put }),
      expected_form_attributes + expected_input_attributes
  end


  # FIXME: This test is janky as hell.  We are essentially rewriting capture and concat and they don't really work right
  # because output is out of order.  This test passes because it's only doing a regex match on the buffer, but this really
  # needs to be fixed by using the real helper methods that rails provides.  capture, concat, url_for etc. should be
  # implemented by their *real* methods or we need to find a better workaround so that our tests aren't written so
  # poorly.  - BR
  test "form_remote_tag with block in erb" do
    def capture(*args, &block)
      @buffer = []
      block.call(*args) if block_given?
    end
    def concat(str)
      @buffer << str
    end

    expected_form_attributes = %w(form action="/url/hash" method="post" data-js-type="remote" data-update-success="#glass_of_beer" /form)
    expected_inner_html = %w(w00t!)

    form_remote_tag(:update => "#glass_of_beer", :url => { :action => :fast  }) { concat expected_inner_html }
    assert_html @buffer.to_s,
      expected_form_attributes + expected_inner_html
  end

class Author
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id

  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new author' : "author ##{@id}"
  end
end

class Article
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_reader :id
  attr_reader :author_id
  def save; @id = 1; @author_id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new article' : "article ##{@id}"
  end
end

class ExtractRemoteAttributesTest < AjaxTestCase
  attr_reader :attributes

  test "extract_remote_attributes! html" do
    attributes = extract_remote_attributes!(:html => { :class => "css_klass", :style => "border:1px solid"})
    assert_equal "css_klass", attributes[:class]
    assert_equal "border:1px solid", attributes[:style]
  end

  test "extract_remote_attributes! update options when :update is a hash" do
    attributes = extract_remote_attributes!(:update => { :success => "foo", :failure => "bar" })
    assert_equal "foo", attributes["data-update-success"]
    assert_equal "bar", attributes["data-update-failure"]
  end

  test "extract_remote_attributes! update options when :update is string" do
    attributes = extract_remote_attributes!(:update => "baz")
    assert_equal "baz", attributes["data-update-success"]
  end

  test "extract_remote_attributes! position" do
    attributes = extract_remote_attributes!(:position => "before")
    assert_equal "before", attributes["data-update-position"]
  end

  test "extract_remote_attributes! data-js-type when it is NOT passed" do
    attributes = extract_remote_attributes!({})
    assert_equal "remote", attributes["data-js-type"]
  end

  test "extract_remote_attributes! data-js-type when it passed" do
    attributes = extract_remote_attributes!(:js_type => "some_type")
    assert_equal "some_type", attributes["data-js-type"]
  end
end

class RemoteFormForTest < AjaxTestCase

  def setup
    super
    @record = @author = Author.new
    @article = Article.new
  end

  test "remote_form_for with record identification with new record" do
    remote_form_for(@record, {:html => { :id => 'create-author' }}) {}

    expected = %(<form action="/authors" data-js-type="remote" class="new_author" id="create-author" method="post"></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with record identification without html options" do
    remote_form_for(@record) {}

    expected = %(<form action="/authors" data-js-type="remote" class="new_author" id="new_author" method="post"></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with record identification with existing record" do
    @record.save
    remote_form_for(@record) {}

    expected = %(<form action="/authors/1" data-js-type="remote" class="edit_author" id="edit_author_1" method="post"><div style="margin:0;padding:0;display:inline"><input name="_method" type="hidden" value="put" /></div></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with new object in list" do
    remote_form_for([@author, @article]) {}

    expected = %(<form action="#{author_articles_path(@author)}" class="new_article" method="post" id="new_article" data-js-type="remote"></form>)
    assert_dom_equal expected, output_buffer
  end

  test "remote_form_for with existing object in list" do
    @author.save
    @article.save
    remote_form_for([@author, @article]) {}

    expected = %(<form action='#{author_article_path(@author, @article)}' id='edit_article_1' method='post' class='edit_article' data-js-type="remote"><div style='margin:0;padding:0;display:inline'><input name='_method' type='hidden' value='put' /></div></form>)
    assert_dom_equal expected, output_buffer
  end

  protected
    def author_path(record)
      "/authors/#{record.id}"
    end

    def authors_path
      "/authors"
    end

    def author_articles_path(author)
      "/authors/#{author.id}/articles"
    end

    def author_article_path(author, article)
      "/authors/#{author.id}/articles/#{article.id}"
    end
end

class ButtonToRemoteTest < AjaxTestCase
  def button(options, html = {})
    button_to_remote("RemoteOutpost", options, html)
  end

  def url_for(*)
    "/whatnot"
  end
  
  class StandardTest < ButtonToRemoteTest
    test "basic" do
      assert_html button({:url => {:action => "whatnot"}}, {:class => "fine", :value => "RemoteOutpost"}),
        %w(input class="fine" type="button" value="RemoteOutpost" data-url="/url/hash")
    end
  end
  
  class LegacyButtonToRemoteTest < ButtonToRemoteTest
    include ActionView::Helpers::AjaxHelper::Rails2Compatibility
    
    assert_callbacks_work do |callback|
      button(callback => "undoRequestCompleted(request)")
    end
  end
end

class SubmitToRemoteTest < AjaxTestCase
  test "basic" do
    expected = %(<input class="fine" type="submit" name="foo" value="bar" data-url="/url/hash" data-js-type="remote" data-update-success=".klass" />)
    options = { :url => {:action => "whatnot"}, :update => ".klass", :html => { :class => "fine" } }

    assert_dom_equal expected,
      submit_to_remote("foo", "bar", options)
  end
end

class ScriptDecoratorTest < AjaxTestCase
  def decorator()
    script_decorator("data-js-type" => "foo_type", "data-foo" => "bar", "data-baz" => "bang")
  end

  test "basic" do
    expected = %(<script type="application/json" data-js-type="foo_type" data-foo="bar" data-baz="bang"></script>)
    assert_dom_equal expected, decorator
  end
end

class ObserveFieldTest < AjaxTestCase
  def protect_against_forgery?
    false
  end

  def field(options = {})
    observe_field("title", options)
  end

  test "basic" do
    assert_html field,
      %w(script type="application/json" data-js-type="field_observer")
  end

  test "using a url string" do
    assert_html field(:url => "/some/other/url"),
      %w(script data-js-type="field_observer" data-url="/some/other/url" data-observed="title")
  end

  test "using a url hash" do
    assert_html field(:url => {:controller => :blog, :action => :update}),
      %w(script data-js-type="field_observer" data-url="/url/hash" data-observed="title")
  end

  test "using a :frequency option" do
    assert_html field(:url => { :controller => :blog }, :frequency => 5.minutes),
      %w(script data-js-type="field_observer" data-url="/url/hash" data-observed="title" data-frequency="300")
  end

  test "using a :frequency option of 0" do
    assert_no_match /frequency/, field(:frequency => 0)
  end

  test "observe field with common options" do
    assert_html observe_field("glass", :frequency => 5.minutes, :url => { :action => "reorder_if_empty" }),
      %w(script data-js-type="field_observer" data-observed="glass" data-frequency="300" data-url="/url/hash")
  end

  # TODO: Consider using JSON instead of strings.  Is using 'value' as a magical reference to the value of the observed field weird? (Rails2 does this) - BR
  test "using a :with option" do
    assert_html field(:with => "foo"),
      %w(script data-js-type="field_observer" data-observed="title" data-with="'foo=' + encodeURIComponent(value)")

    assert_html field(:with => "'foo=' + encodeURIComponent(value)"),
      %w(script data-js-type="field_observer" data-observed="title" data-with="'foo=' + encodeURIComponent(value)")
  end

  test "using json in a :with option" do
    assert_html field(:with => "{'id':value}"),
      %w(script data-js-type="field_observer" data-observed="title" data-with="{'id':value}")
  end

  test "using :function for callback" do
    assert_html field(:function => "alert('Element changed')"),
      %w(script data-js-type="field_observer" data-observer-code="function(element, value) {alert('Element changed')}")
  end
end

class ObserveFormTest < AjaxTestCase
  test "basic" do
    assert_html observe_form("some_form", :frequency => 2, :url => { :action => "hash" }),
      %w(script data-js-type="form_observer" data-url="/url/hash" data-observed="some_form" data-frequency="2")
  end
end

class PeriodicallyCallRemoteTest < AjaxTestCase
  test "basic" do
    assert_html periodically_call_remote(:update => "#schremser_bier", :url => { :action => "mehr_bier" }),
      %w(script data-url="/url/hash" data-update-success="#schremser_bier")
  end

  test "periodically call remote with :frequency" do
    assert_html periodically_call_remote(:frequency => 2, :url => "/url/string"),
      %w(script data-url="/url/string" data-frequency="2")
  end
end
