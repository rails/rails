require "abstract_unit"

#TODO: Switch to assert_dom_equal where appropriate.  assert_html is not robust enough for all tests - BR

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

  def extract_json_from_data_element(data_element)
    root = HTML::Document.new(data_element).root
    script = root.find(:tag => "script")
    cdata = script.children.detect {|child| child.to_s =~ /<!\[CDATA\[/ }
    js = cdata.content.split("\n").map {|line| line.gsub(Regexp.new("//.*"), "")}.join("\n").strip!

    ActiveSupport::JSON.decode(js)
  end

  def assert_data_element_json(actual, expected)
    json = extract_json_from_data_element(actual)
    assert_equal expected, json
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
    assert_html form_remote_tag(:update => "#glass_of_beer", :url => { :action => :fast  }),
      %w(form action="/url/hash" method="post" data-js-type="remote" data-update-success="#glass_of_beer")
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
<<<<<<< HEAD
    expected_form_attributes = %w(form action="/url/hash" method="post" data-remote="true" data-update-success="#glass_of_beer")
    # TODO: Ask Katz: Why does rails do this?  Some web servers don't allow PUT or DELETE from what I remember... - BR
=======
    expected_form_attributes = %w(form action="/url/hash" method="post" data-js-type="remote" data-update-success="#glass_of_beer")
    # TODO: Experiment with not using this _method param.  Apparently this is done to address browser incompatibilities, but since
    # we have a layer between the HTML and the JS libs now, we can probably get away with letting JS the JS libs handle the requirement
    # for an extra field if needed.
>>>>>>> 6af9c2f... Changed data-remote='true' to data-js-type='remote'
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
    button_to_remote("Remote outpost", options, html)
  end

  def url_for(*)
    "/whatnot"
  end
  
  class StandardTest < ButtonToRemoteTest
    test "basic" do
      button = button({:url => {:action => "whatnot"}}, {:class => "fine"})
      [/input/, /class="fine"/, /type="button"/, /value="Remote outpost"/,
       /data-url="\/whatnot"/].each do |match|
         assert_match match, button
      end
    end
  end
  
  class LegacyButtonToRemoteTest < ButtonToRemoteTest
    include ActionView::Helpers::AjaxHelper::Rails2Compatibility
    
    assert_callbacks_work do |callback|
      button(callback => "undoRequestCompleted(request)")
    end
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
      %w(script type="application/json" data-js-type="observe_field")
  end

  test "using a url string" do
    assert_data_element_json field(:url => "/some/other/url"),
      "url" => "/some/other/url", "name" => "title"
  end

  test "using a url hash" do
    assert_data_element_json field(:url => {:controller => :blog, :action => :update}),
      "url" => "/url/hash", "name" => "title"
  end

  test "using a :frequency option" do
    assert_data_element_json field(:url => { :controller => :blog }, :frequency => 5.minutes),
      "url" => "/url/hash", "name" => "title", "frequency" => 300
  end

  test "using a :frequency option of 0" do
    assert_no_match /frequency/, field(:frequency => 0)
  end

  # TODO: Finish when remote_function or some equivilent is finished -BR
#  def test_observe_field
#    assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Form.Element.Observer('glass', 300, function(element, value) {new Ajax.Request('http://www.example.com/reorder_if_empty', {asynchronous:true, evalScripts:true, parameters:value})})\n//]]>\n</script>),
#      observe_field("glass", :frequency => 5.minutes, :url => { :action => "reorder_if_empty" })
#  end

  # TODO: Consider using JSON instead of strings.  Is using 'value' as a magical reference to the value of the observed field weird? (Rails2 does this) - BR
  test "using a :with option" do
    assert_data_element_json field(:with => "foo"),
      "name" => "title", "with" => "'foo=' + encodeURIComponent(value)"
    assert_data_element_json field(:with => "'foo=' + encodeURIComponent(value)"),
      "name" => "title", "with" => "'foo=' + encodeURIComponent(value)"
  end

  test "using json in a :with option" do
    assert_data_element_json field(:with => "{'id':value}"),
      "name" => "title", "with" => "{'id':value}"
  end

  test "using :function for callback" do
    assert_data_element_json field(:function => "alert('Element changed')"),
      "name" => "title", "function" => "function(element, value) {alert('Element changed')}"
  end
end
