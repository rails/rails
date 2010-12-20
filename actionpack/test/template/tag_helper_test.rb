require 'abstract_unit'

class TagHelperTest < ActionView::TestCase
  tests ActionView::Helpers::TagHelper

  def test_tag
    assert_equal "<br />", tag("br")
    assert_equal "<br clear=\"left\" />", tag(:br, :clear => "left")
    assert_equal "<br>", tag("br", nil, true)
  end

  def test_tag_options
    str = tag("p", "class" => "show", :class => "elsewhere")
    assert_match(/class="show"/, str)
    assert_match(/class="elsewhere"/, str)
  end

  def test_tag_options_rejects_nil_option
    assert_equal "<p />", tag("p", :ignored => nil)
  end

  def test_tag_options_accepts_false_option
    assert_equal "<p value=\"false\" />", tag("p", :value => false)
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
    assert content_tag("a", "Create", "href" => "create").html_safe?
    assert_equal content_tag("a", "Create", "href" => "create"),
                 content_tag("a", "Create", :href => "create")
    assert_equal "<p>&lt;script&gt;evil_js&lt;/script&gt;</p>",
                 content_tag(:p, '<script>evil_js</script>')
    assert_equal "<p><script>evil_js</script></p>",
                 content_tag(:p, '<script>evil_js</script>', nil, false)
  end

  def test_content_tag_with_block_in_erb
    buffer = content_tag(:div) { concat "Hello world!" }
    assert_dom_equal "<div>Hello world!</div>", buffer
  end

  def test_content_tag_with_block_and_options_in_erb
    buffer = content_tag(:div, :class => "green") { concat "Hello world!" }
    assert_dom_equal %(<div class="green">Hello world!</div>), buffer
  end

  def test_content_tag_with_block_and_options_out_of_erb
    assert_dom_equal %(<div class="green">Hello world!</div>), content_tag(:div, :class => "green") { "Hello world!" }
  end

  def test_content_tag_with_block_and_options_outside_out_of_erb
    assert_equal content_tag("a", "Create", :href => "create"),
                 content_tag("a", "href" => "create") { "Create" }
  end

  def test_content_tag_nested_in_content_tag_out_of_erb
    assert_equal content_tag("p", content_tag("b", "Hello")),
                 content_tag("p") { content_tag("b", "Hello") },
                 output_buffer
  end

  # TAG TODO: Move this into a real template
  def test_content_tag_nested_in_content_tag_in_erb
    buffer = content_tag("p") { concat content_tag("b", "Hello") }
    assert_equal '<p><b>Hello</b></p>', buffer
  end

  def test_content_tag_with_escaped_array_class
    str = content_tag('p', "limelight", :class => ["song", "play>"])
    assert_equal "<p class=\"song play&gt;\">limelight</p>", str

    str = content_tag('p', "limelight", :class => ["song", "play"])
    assert_equal "<p class=\"song play\">limelight</p>", str
  end

  def test_content_tag_with_unescaped_array_class
    str = content_tag('p', "limelight", {:class => ["song", "play>"]}, false)
    assert_equal "<p class=\"song play>\">limelight</p>", str
  end

  def test_cdata_section
    assert_equal "<![CDATA[<hello world>]]>", cdata_section("<hello world>")
  end

  def test_escape_once
    assert_equal '1 &lt; 2 &amp; 3', escape_once('1 < 2 &amp; 3')
  end

  def test_tag_honors_html_safe_for_param_values
    ['1&amp;2', '1 &lt; 2', '&#8220;test&#8220;'].each do |escaped|
      assert_equal %(<a href="#{escaped}" />), tag('a', :href => escaped.html_safe)
    end
  end

  def test_skip_invalid_escaped_attributes
    ['&1;', '&#1dfa3;', '& #123;'].each do |escaped|
      assert_equal %(<a href="#{escaped.gsub(/&/, '&amp;')}" />), tag('a', :href => escaped)
    end
  end

  def test_disable_escaping
    assert_equal '<a href="&amp;" />', tag('a', { :href => '&amp;' }, false, false)
  end

  def test_data_attributes
    ['data', :data].each { |data|
      assert_dom_equal '<a data-a-number="1" data-array="[1,2,3]" data-hash="{&quot;key&quot;:&quot;value&quot;}" data-string="hello" data-symbol="foo" />',
        tag('a', { data => { :a_number => 1, :string => 'hello', :symbol => :foo, :array => [1, 2, 3], :hash => { :key => 'value'} } })
    }
  end

  def test_add_css_class
    # tolerant of nils
    assert_equal "", add_css_class(nil, nil)
    assert_equal "a", add_css_class("a", nil)
    assert_equal "a", add_css_class(nil, "a")
    # joined with a space
    assert_equal "a b", add_css_class("a", "b")
    # output is sorted
    assert_equal "a b", add_css_class("b", "a")
    # symbols work too
    assert_equal "a b", add_css_class(:b, :a)
    # several classes can be specified per argument
    assert_equal "a b c d", add_css_class("b c", "a d")
    # Any number of arguments are accepted, and the output should be uniq'd
    assert_equal "a b", add_css_class("a", "b", "b a")
  end

  def test_merge_tag_attributes!
    attributes = {}

    merge_tag_attributes!(attributes, :class => "a", :id => "id")
    assert_equal({:class => "a", :id => "id"}, attributes)

    merge_tag_attributes!(attributes, :class => "b", :id => "id2")
    assert_equal({:class => "a b", :id => "id2"}, attributes)

    # Style attribute gets merged with semi-colon separators
    attributes = {:style => "color: red;"} #with a semicolon
    merge_tag_attributes!(attributes, :style => "font-weight: bold")
    assert_equal({:style => "color: red; font-weight: bold"}, attributes)

    attributes = {:style => "color: red"} #without a semicolon
    merge_tag_attributes!(attributes, :style => "font-weight: bold")
    assert_equal({:style => "color: red; font-weight: bold"}, attributes)

    # Event attributes gets merged with semi-colon separators
    attributes = {:onclick => "alert('hello');"} #with a semicolon
    merge_tag_attributes!(attributes, :onclick => "alert('world');")
    assert_equal({:onclick => "alert('hello'); alert('world')"}, attributes)

    attributes = {:onclick => "alert('hello')"} #without a semicolon
    merge_tag_attributes!(attributes, :onclick => "alert('world');")
    assert_equal({:onclick => "alert('hello'); alert('world')"}, attributes)

    # Make sure it handles nil
    assert_equal({:class=>"a"}, merge_tag_attributes!({:class=>"a"}, nil))
    assert_equal({:class=>"a"}, merge_tag_attributes!(nil, {:class=>"a"}))
  end

  def test_merge_tag_attributes
    attributes = {}
    # Make sure the returned value is merged
    assert_equal({:class=>"a"}, merge_tag_attributes(attributes, :class => "a"))
    # Make sure it handles nil
    assert_equal({:class=>"a"}, merge_tag_attributes({:class=>"a"}, nil))
    assert_equal({:class=>"a"}, merge_tag_attributes(nil, {:class=>"a"}))
    # but the original value is unchanged
    assert_equal({}, attributes)
  end

end
