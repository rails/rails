require 'abstract_unit'

class JavaScriptHelperTest < ActionView::TestCase
  tests ActionView::Helpers::JavaScriptHelper

  def _evaluate_assigns_and_ivars() end

  attr_accessor :formats, :output_buffer

  def update_details(details)
    @details = details
    yield if block_given?
  end

  def setup
    super
    ActiveSupport.escape_html_entities_in_json  = true
    @template = self
  end

  def teardown
    ActiveSupport.escape_html_entities_in_json  = false
  end

  def test_escape_javascript
    assert_equal '', escape_javascript(nil)
    assert_equal %(This \\"thing\\" is really\\n netos\\'), escape_javascript(%(This "thing" is really\n netos'))
    assert_equal %(backslash\\\\test), escape_javascript( %(backslash\\test) )
    assert_equal %(dont <\\/close> tags), escape_javascript(%(dont </close> tags))
    assert_equal %(unicode &#x2028; newline), escape_javascript(%(unicode \342\200\250 newline).force_encoding(Encoding::UTF_8).encode!)
    assert_equal %(unicode &#x2029; newline), escape_javascript(%(unicode \342\200\251 newline).force_encoding(Encoding::UTF_8).encode!)

    assert_equal %(dont <\\/close> tags), j(%(dont </close> tags))
  end

  def test_escape_javascript_with_safebuffer
    given = %('quoted' "double-quoted" new-line:\n </closed>)
    expect = %(\\'quoted\\' \\"double-quoted\\" new-line:\\n <\\/closed>)
    assert_equal expect, escape_javascript(given)
    assert_equal expect, escape_javascript(ActiveSupport::SafeBuffer.new(given))
    assert_instance_of String, escape_javascript(given)
    assert_instance_of ActiveSupport::SafeBuffer, escape_javascript(ActiveSupport::SafeBuffer.new(given))
  end

  def test_button_to_function
    assert_deprecated do
      assert_dom_equal %(<input type="button" onclick="alert(&#39;Hello world!&#39;);" value="Greeting" />),
        button_to_function("Greeting", "alert('Hello world!')")
    end
  end

  def test_button_to_function_with_onclick
    assert_deprecated do
      assert_dom_equal "<input onclick=\"alert(&#39;Goodbye World :(&#39;); alert(&#39;Hello world!&#39;);\" type=\"button\" value=\"Greeting\" />",
        button_to_function("Greeting", "alert('Hello world!')", :onclick => "alert('Goodbye World :(')")
    end
  end

  def test_button_to_function_without_function
    assert_deprecated do
      assert_dom_equal "<input onclick=\";\" type=\"button\" value=\"Greeting\" />",
        button_to_function("Greeting")
    end
  end

  def test_link_to_function
    assert_deprecated do
      assert_dom_equal %(<a href="#" onclick="alert(&#39;Hello world!&#39;); return false;">Greeting</a>),
        link_to_function("Greeting", "alert('Hello world!')")
    end
  end

  def test_link_to_function_with_existing_onclick
    assert_deprecated do
      assert_dom_equal %(<a href="#" onclick="confirm(&#39;Sanity!&#39;); alert(&#39;Hello world!&#39;); return false;">Greeting</a>),
        link_to_function("Greeting", "alert('Hello world!')", :onclick => "confirm('Sanity!')")
    end
  end

  def test_function_with_href
    assert_deprecated do
      assert_dom_equal %(<a href="http://example.com/" onclick="alert(&#39;Hello world!&#39;); return false;">Greeting</a>),
        link_to_function("Greeting", "alert('Hello world!')", :href => 'http://example.com/')
    end
  end

  def test_javascript_tag
    self.output_buffer = 'foo'

    assert_dom_equal "<script>\n//<![CDATA[\nalert('hello')\n//]]>\n</script>",
      javascript_tag("alert('hello')")

    assert_equal 'foo', output_buffer, 'javascript_tag without a block should not concat to output_buffer'
  end

  def test_javascript_tag_with_options
    assert_dom_equal "<script id=\"the_js_tag\">\n//<![CDATA[\nalert('hello')\n//]]>\n</script>",
      javascript_tag("alert('hello')", :id => "the_js_tag")
  end

  def test_javascript_cdata_section
    assert_dom_equal "\n//<![CDATA[\nalert('hello')\n//]]>\n", javascript_cdata_section("alert('hello')")
  end
end
