# frozen_string_literal: true

require "abstract_unit"

class JavaScriptHelperTest < ActionView::TestCase
  tests ActionView::Helpers::JavaScriptHelper

  attr_accessor :output_buffer
  attr_reader :request

  setup do
    @old_escape_html_entities_in_json = ActiveSupport.escape_html_entities_in_json
    @old_auto_include_nonce = ActionView::Helpers::JavaScriptHelper.auto_include_nonce
    ActiveSupport.escape_html_entities_in_json = true
    @template = self
    @request = Class.new do
      def send_early_hints(links) end
    end.new
  end

  def teardown
    ActiveSupport.escape_html_entities_in_json = @old_escape_html_entities_in_json
    ActionView::Helpers::JavaScriptHelper.auto_include_nonce = @old_auto_include_nonce
  end

  def test_escape_javascript
    assert_equal "", escape_javascript(nil)
    assert_equal "123", escape_javascript(123)
    assert_equal "en", escape_javascript(:en)
    assert_equal "false", escape_javascript(false)
    assert_equal "true", escape_javascript(true)
    assert_equal %(This \\"thing\\" is really\\n netos\\'), escape_javascript(%(This "thing" is really\n netos'))
    assert_equal %(backslash\\\\test), escape_javascript(%(backslash\\test))
    assert_equal %(don\\'t <\\/close> tags), escape_javascript(%(don't </close> tags))
    assert_equal %(unicode &#x2028; newline), escape_javascript((+%(unicode \342\200\250 newline)).force_encoding(Encoding::UTF_8).encode!)
    assert_equal %(unicode &#x2029; newline), escape_javascript((+%(unicode \342\200\251 newline)).force_encoding(Encoding::UTF_8).encode!)

    assert_equal %(don\\'t <\\/close> tags), j(%(don't </close> tags))
  end

  def test_escape_backtick
    assert_equal "\\`", escape_javascript("`")
  end

  def test_escape_dollar_sign
    assert_equal "\\$", escape_javascript("$")
  end

  def test_escape_javascript_with_safebuffer
    given = %('quoted' "double-quoted" new-line:\n </closed>)
    expect = %(\\'quoted\\' \\"double-quoted\\" new-line:\\n <\\/closed>)
    assert_equal expect, escape_javascript(given)
    assert_equal expect, escape_javascript(ActiveSupport::SafeBuffer.new(given))
    assert_instance_of String, escape_javascript(given)
    assert_instance_of ActiveSupport::SafeBuffer, escape_javascript(ActiveSupport::SafeBuffer.new(given))
  end

  def test_javascript_tag
    self.output_buffer = "foo"

    assert_dom_equal "<script>\n//<![CDATA[\nalert('hello')\n//]]>\n</script>",
      javascript_tag("alert('hello')")

    assert_equal "foo", output_buffer, "javascript_tag without a block should not concat to output_buffer"
  end

  # Setting the :extname option will control what extension (if any) is appended to the URL for assets
  def test_javascript_include_tag
    assert_dom_equal "<script src='/foo.js'></script>",  javascript_include_tag("/foo")
    assert_dom_equal "<script src='/foo'></script>",     javascript_include_tag("/foo", extname: false)
    assert_dom_equal "<script src='/foo.bar'></script>", javascript_include_tag("/foo", extname: ".bar")
  end

  def test_javascript_tag_with_options
    assert_dom_equal "<script id=\"the_js_tag\">\n//<![CDATA[\nalert('hello')\n//]]>\n</script>",
      javascript_tag("alert('hello')", id: "the_js_tag")
  end

  def test_javascript_cdata_section
    assert_dom_equal "\n//<![CDATA[\nalert('hello')\n//]]>\n", javascript_cdata_section("alert('hello')")
  end

  def test_javascript_tag_with_auto_nonce_for_content_security_policy
    instance_eval { def content_security_policy_nonce = "iyhD0Yc0W+c=" }
    ActionView::Helpers::JavaScriptHelper.auto_include_nonce = true

    assert_dom_equal "<script nonce=\"iyhD0Yc0W+c=\">\n//<![CDATA[\nalert('hello')\n//]]>\n</script>",
      javascript_tag("alert('hello')")
  end
end
