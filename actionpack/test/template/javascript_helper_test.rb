require 'abstract_unit'

class JavaScriptHelperTest < ActionView::TestCase
  tests ActionView::Helpers::JavaScriptHelper

  attr_accessor :template_format, :output_buffer

  def setup
    @template = self
  end

  def test_escape_javascript
    assert_equal '', escape_javascript(nil)
    assert_equal %(This \\"thing\\" is really\\n netos\\'), escape_javascript(%(This "thing" is really\n netos'))
    assert_equal %(backslash\\\\test), escape_javascript( %(backslash\\test) )
    assert_equal %(dont <\\/close> tags), escape_javascript(%(dont </close> tags))
  end

  def test_javascript_tag
    self.output_buffer = 'foo'

    assert_dom_equal "<script type=\"text/javascript\">\n//<![CDATA[\nalert('hello')\n//]]>\n</script>",
      javascript_tag("alert('hello')")

    assert_equal 'foo', output_buffer, 'javascript_tag without a block should not concat to output_buffer'
  end

  def test_javascript_tag_with_options
    assert_dom_equal "<script id=\"the_js_tag\" type=\"text/javascript\">\n//<![CDATA[\nalert('hello')\n//]]>\n</script>",
      javascript_tag("alert('hello')", :id => "the_js_tag")
  end

  def test_javascript_tag_with_block_in_erb
    failed_pre_200

    __in_erb_template = ''
    javascript_tag { concat "alert('hello')" }
    assert_dom_equal "<script type=\"text/javascript\">\n//<![CDATA[\nalert('hello')\n//]]>\n</script>", output_buffer
  end

  def test_javascript_tag_with_block_and_options_in_erb
    failed_pre_200

    __in_erb_template = ''
    javascript_tag(:id => "the_js_tag") { concat "alert('hello')" }
    assert_dom_equal "<script id=\"the_js_tag\" type=\"text/javascript\">\n//<![CDATA[\nalert('hello')\n//]]>\n</script>", output_buffer
  end

  def test_javascript_cdata_section
    assert_dom_equal "\n//<![CDATA[\nalert('hello')\n//]]>\n", javascript_cdata_section("alert('hello')")
  end
end
