require 'abstract_unit'

class OutputSafetyHelperTest < ActionView::TestCase
  tests ActionView::Helpers::OutputSafetyHelper

  def setup
    @string = "hello"
  end

  test "raw returns the safe string" do
    result = raw(@string)
    assert_equal @string, result
    assert result.html_safe?
  end

  test "raw handles nil values correctly" do
    assert_equal "", raw(nil)
  end

  test "safe_join should html_escape any items, including the separator, if they are not html_safe" do
    joined = safe_join(["<p>foo</p>".html_safe, "<p>bar</p>"], "<br />")
    assert_equal "<p>foo</p>&lt;br /&gt;&lt;p&gt;bar&lt;/p&gt;", joined

    joined = safe_join(["<p>foo</p>".html_safe, "<p>bar</p>".html_safe], "<br />".html_safe)
    assert_equal "<p>foo</p><br /><p>bar</p>", joined
  end

end