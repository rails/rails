# encoding: utf-8
#--
# Copyright (c) 2006 Assaf Arkin (http://labnotes.org)
# Under MIT and/or CC By license.
#++

require 'abstract_unit'
require 'controller/fake_controllers'

require 'action_mailer'
ActionMailer::Base.view_paths = FIXTURE_LOAD_PATH

class AssertSelectTest < ActionController::TestCase
  Assertion = ActiveSupport::TestCase::Assertion

  class AssertSelectMailer < ActionMailer::Base
    def test(html)
      mail :body => html, :content_type => "text/html",
        :subject => "Test e-mail", :from => "test@test.host", :to => "test <test@test.host>"
    end
  end

  class AssertMultipartSelectMailer < ActionMailer::Base
    def test(options)
      mail :subject => "Test e-mail", :from => "test@test.host", :to => "test <test@test.host>" do |format|
        format.text { render :text => options[:text] }
        format.html { render :text => options[:html] }
      end
    end
  end

  class AssertSelectController < ActionController::Base
    def response_with=(content)
      @content = content
    end

    def response_with(&block)
      @update = block
    end

    def html()
      render :text=>@content, :layout=>false, :content_type=>Mime::HTML
      @content = nil
    end

    def xml()
      render :text=>@content, :layout=>false, :content_type=>Mime::XML
      @content = nil
    end

    def rescue_action(e)
      raise e
    end
  end

  tests AssertSelectController

  def setup
    super
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def teardown
    super
    ActionMailer::Base.deliveries.clear
  end

  def assert_failure(message, &block)
    e = assert_raise(Assertion, &block)
    assert_match(message, e.message) if Regexp === message
    assert_equal(message, e.message) if String === message
  end

  #
  # Test assert select.
  #

  def test_assert_select
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_select "div", 2
    assert_failure(/Expected at least 1 element matching \"p\", found 0/) { assert_select "p" }
  end

  def test_equality_integer
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_failure(/Expected exactly 3 elements matching \"div\", found 2/) { assert_select "div", 3 }
    assert_failure(/Expected exactly 0 elements matching \"div\", found 2/) { assert_select "div", 0 }
  end

  def test_equality_true_false
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_nothing_raised    { assert_select "div" }
    assert_raise(Assertion) { assert_select "p" }
    assert_nothing_raised    { assert_select "div", true }
    assert_raise(Assertion) { assert_select "p", true }
    assert_raise(Assertion) { assert_select "div", false }
    assert_nothing_raised    { assert_select "p", false }
  end

  def test_equality_false_message
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_failure(/Expected exactly 0 elements matching \"div\", found 2/) { assert_select "div", false }
  end

  def test_equality_string_and_regexp
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_nothing_raised    { assert_select "div", "foo" }
    assert_raise(Assertion) { assert_select "div", "bar" }
    assert_nothing_raised    { assert_select "div", :text=>"foo" }
    assert_raise(Assertion) { assert_select "div", :text=>"bar" }
    assert_nothing_raised    { assert_select "div", /(foo|bar)/ }
    assert_raise(Assertion) { assert_select "div", /foobar/ }
    assert_nothing_raised    { assert_select "div", :text=>/(foo|bar)/ }
    assert_raise(Assertion) { assert_select "div", :text=>/foobar/ }
    assert_raise(Assertion) { assert_select "p", :text=>/foobar/ }
  end

  def test_equality_of_html
    render_html %Q{<p>\n<em>"This is <strong>not</strong> a big problem,"</em> he said.\n</p>}
    text = "\"This is not a big problem,\" he said."
    html = "<em>\"This is <strong>not</strong> a big problem,\"</em> he said."
    assert_nothing_raised    { assert_select "p", text }
    assert_raise(Assertion) { assert_select "p", html }
    assert_nothing_raised    { assert_select "p", :html=>html }
    assert_raise(Assertion) { assert_select "p", :html=>text }
    # No stripping for pre.
    render_html %Q{<pre>\n<em>"This is <strong>not</strong> a big problem,"</em> he said.\n</pre>}
    text = "\n\"This is not a big problem,\" he said.\n"
    html = "\n<em>\"This is <strong>not</strong> a big problem,\"</em> he said.\n"
    assert_nothing_raised    { assert_select "pre", text }
    assert_raise(Assertion) { assert_select "pre", html }
    assert_nothing_raised    { assert_select "pre", :html=>html }
    assert_raise(Assertion) { assert_select "pre", :html=>text }
  end

  def test_strip_textarea
    render_html %Q{<textarea>\n\nfoo\n</textarea>}
    assert_select "textarea", "\nfoo\n"
    render_html %Q{<textarea>\nfoo</textarea>}
    assert_select "textarea", "foo"
  end

  def test_counts
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_nothing_raised               { assert_select "div", 2 }
    assert_failure(/Expected exactly 3 elements matching \"div\", found 2/) do
      assert_select "div", 3
    end
    assert_nothing_raised               { assert_select "div", 1..2 }
    assert_failure(/Expected between 3 and 4 elements matching \"div\", found 2/) do
      assert_select "div", 3..4
    end
    assert_nothing_raised               { assert_select "div", :count=>2 }
    assert_failure(/Expected exactly 3 elements matching \"div\", found 2/) do
      assert_select "div", :count=>3
    end
    assert_nothing_raised               { assert_select "div", :minimum=>1 }
    assert_nothing_raised               { assert_select "div", :minimum=>2 }
    assert_failure(/Expected at least 3 elements matching \"div\", found 2/) do
      assert_select "div", :minimum=>3
    end
    assert_nothing_raised               { assert_select "div", :maximum=>2 }
    assert_nothing_raised               { assert_select "div", :maximum=>3 }
    assert_failure(/Expected at most 1 element matching \"div\", found 2/) do
      assert_select "div", :maximum=>1
    end
    assert_nothing_raised               { assert_select "div", :minimum=>1, :maximum=>2 }
    assert_failure(/Expected between 3 and 4 elements matching \"div\", found 2/) do
      assert_select "div", :minimum=>3, :maximum=>4
    end
  end

  def test_substitution_values
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_select "div#?", /\d+/ do |elements|
      assert_equal 2, elements.size
    end
    assert_select "div" do
      assert_select "div#?", /\d+/ do |elements|
        assert_equal 2, elements.size
        assert_select "#1"
        assert_select "#2"
      end
    end
  end

  def test_nested_assert_select
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_select "div" do |elements|
      assert_equal 2, elements.size
      assert_select elements[0], "#1"
      assert_select elements[1], "#2"
    end
    assert_select "div" do
      assert_select "div" do |elements|
        assert_equal 2, elements.size
        # Testing in a group is one thing
        assert_select "#1,#2"
        # Testing individually is another.
        assert_select "#1"
        assert_select "#2"
        assert_select "#3", false
      end
    end

    assert_failure(/Expected at least 1 element matching \"#4\", found 0\./) do
      assert_select "div" do
        assert_select "#4"
      end
    end
  end

  def test_assert_select_text_match
    render_html %Q{<div id="1"><span>foo</span></div><div id="2"><span>bar</span></div>}
    assert_select "div" do
      assert_nothing_raised    { assert_select "div", "foo" }
      assert_nothing_raised    { assert_select "div", "bar" }
      assert_nothing_raised    { assert_select "div", /\w*/ }
      assert_nothing_raised    { assert_select "div", :text => /\w*/, :count=>2 }
      assert_raise(Assertion)  { assert_select "div", :text=>"foo", :count=>2 }
      assert_nothing_raised    { assert_select "div", :html=>"<span>bar</span>" }
      assert_nothing_raised    { assert_select "div", :html=>"<span>bar</span>" }
      assert_nothing_raised    { assert_select "div", :html=>/\w*/ }
      assert_nothing_raised    { assert_select "div", :html=>/\w*/, :count=>2 }
      assert_raise(Assertion)  { assert_select "div", :html=>"<span>foo</span>", :count=>2 }
    end
  end

  def test_elect_with_xml_namespace_attributes
    render_html %Q{<link xlink:href="http://nowhere.com"></link>}
    assert_nothing_raised { assert_select "link[xlink:href=http://nowhere.com]" }
  end

  #
  # Test css_select.
  #

  def test_css_select
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_equal 2, css_select("div").size
    assert_equal 0, css_select("p").size
  end

  def test_nested_css_select
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_select "div#?", /\d+/ do |elements|
      assert_equal 1, css_select(elements[0], "div").size
      assert_equal 1, css_select(elements[1], "div").size
    end
    assert_select "div" do
      assert_equal 2, css_select("div").size
      css_select("div").each do |element|
        # Testing as a group is one thing
        assert !css_select("#1,#2").empty?
        # Testing individually is another
        assert !css_select("#1").empty?
        assert !css_select("#2").empty?
      end
    end
  end

  def test_feed_item_encoded
    render_xml <<-EOF
<rss version="2.0">
  <channel>
    <item>
      <description>
        <![CDATA[
          <p>Test 1</p>
        ]]>
      </description>
    </item>
    <item>
      <description>
        <![CDATA[
          <p>Test 2</p>
        ]]>
      </description>
    </item>
  </channel>
</rss>
EOF
    assert_select "channel item description" do
      # Test element regardless of wrapper.
      assert_select_encoded do
        assert_select "p", :count=>2, :text=>/Test/
      end
      # Test through encoded wrapper.
      assert_select_encoded do
        assert_select "encoded p", :count=>2, :text=>/Test/
      end
      # Use :root instead (recommended)
      assert_select_encoded do
        assert_select ":root p", :count=>2, :text=>/Test/
      end
      # Test individually.
      assert_select "description" do |elements|
        assert_select_encoded elements[0] do
          assert_select "p", "Test 1"
        end
        assert_select_encoded elements[1] do
          assert_select "p", "Test 2"
        end
      end
    end

    # Test that we only un-encode element itself.
    assert_select "channel item" do
      assert_select_encoded do
        assert_select "p", 0
      end
    end
  end

  #
  # Test assert_select_email
  #

  def test_assert_select_email
    assert_raise(Assertion) { assert_select_email {} }
    AssertSelectMailer.test("<div><p>foo</p><p>bar</p></div>").deliver
    assert_select_email do
      assert_select "div:root" do
        assert_select "p:first-child", "foo"
        assert_select "p:last-child", "bar"
      end
    end
  end

  def test_assert_select_email_multipart
    AssertMultipartSelectMailer.test(:html => "<div><p>foo</p><p>bar</p></div>", :text => 'foo bar').deliver
    assert_select_email do
      assert_select "div:root" do
        assert_select "p:first-child", "foo"
        assert_select "p:last-child", "bar"
      end
    end
  end

  protected
    def render_html(html)
      @controller.response_with = html
      get :html
    end

    def render_xml(xml)
      @controller.response_with = xml
      get :xml
    end
end
