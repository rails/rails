require "abstract_unit"

class AjaxTestCase < ActiveSupport::TestCase
  include ActionView::Helpers::AjaxHelper
  include ActionView::Helpers::TagHelper

  def assert_html(html, matches)
    matches.each do |match|
      assert_match Regexp.new(Regexp.escape(match)), html
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
    assert_html link, %w(href="/blog/destroy/4" data-update-success="#posts")
  end

  test "with :html options" do
    expected = %{<a href="/blog/destroy/4" data-custom="me" data-remote="true" data-update-success="#posts">Delete this post</a>}
    assert_equal expected, link(:update => "#posts", :html => {"data-custom" => "me"})
  end

  test "with a hash for :update" do
    link = link(:update => {:success => "#posts", :failure => "#error"})
    assert_html link, %w(data-remote="true" data-update-success="#posts" data-update-failure="#error")
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
      expected = %{<a href="/blog/destroy/4" data-remote="true" data-update-success="#posts">Delete this post</a>}
      assert_equal expected,
        link_to_remote("Delete this post", :url => "/blog/destroy/4", :update => "#posts")
    end

    assert_callbacks_work do |callback|
      link(callback => "undoRequestCompleted(request)")
    end
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
      %w(script type="application/json" data-rails-type="observe_field")
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
