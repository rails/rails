require File.dirname(__FILE__) + '/../abstract_unit'

class TagHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::CaptureHelper

  def test_tag
    assert_equal "<br />", tag("br")
    assert_equal "<br clear=\"left\" />", tag(:br, :clear => "left")
    assert_equal "<br>", tag("br", nil, true)
  end

  def test_tag_options
    assert_match /\A<p class="(show|elsewhere)" \/>\z/, tag("p", "class" => "show", :class => "elsewhere")
  end

  def test_tag_options_rejects_nil_option
    assert_equal "<p />", tag("p", :ignored => nil)
  end

  def test_tag_options_accepts_blank_option
    assert_equal "<p included=\"\" />", tag("p", :included => '')
  end

  def test_tag_options_converts_boolean_option
    assert_equal '<p disabled="disabled" multiple="multiple" readonly="readonly" />',
      tag("p", :disabled => true, :multiple => true, :readonly => true)
  end

  def test_content_tag
    assert_equal "<a href=\"create\">Create</a>", content_tag("a", "Create", "href" => "create")
    assert_equal content_tag("a", "Create", "href" => "create"),
                 content_tag("a", "Create", :href => "create")
  end
  
  def test_content_tag_with_block
    _erbout = ''
    content_tag(:div) { _erbout.concat "Hello world!" }
    assert_dom_equal "<div>Hello world!</div>", _erbout
  end
  
  def test_content_tag_with_block_and_options
    _erbout = ''
    content_tag(:div, :class => "green") { _erbout.concat "Hello world!" }
    assert_dom_equal %(<div class="green">Hello world!</div>), _erbout
  end
  
  def test_cdata_section
    assert_equal "<![CDATA[<hello world>]]>", cdata_section("<hello world>")
  end
  
  def test_escape_once
    assert_equal '1 &lt; 2 &amp; 3', escape_once('1 < 2 &amp; 3')
  end
  
  def test_double_escaping_attributes
    ['1&amp;2', '1 &lt; 2', '&#8220;test&#8220;'].each do |escaped|
      assert_equal %(<a href="#{escaped}" />), tag('a', :href => escaped)
    end
  end
  
  def test_skip_invalid_escaped_attributes
    ['&1;', '&#1dfa3;', '& #123;'].each do |escaped|
      assert_equal %(<a href="#{escaped.gsub /&/, '&amp;'}" />), tag('a', :href => escaped)
    end
  end
end
