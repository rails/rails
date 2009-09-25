require 'abstract_unit'

class DomAssertionsTest < ActionView::TestCase
  def setup
    super
    @html_only = '<ul><li>foo</li><li>bar</li></ul>'
    @html_with_meaningless_whitespace = %{
      <ul>
        <li>\tfoo  </li>
        <li>
        bar
        </li>
      </ul>
    }
    @more_html_with_meaningless_whitespace = %{<ul>
      
      <li>foo</li>

<li>bar</li></ul>}
  end
  
  test "assert_dom_equal strips meaningless whitespace from expected string" do
    assert_dom_equal @html_with_meaningless_whitespace, @html_only
  end

  test "assert_dom_equal strips meaningless whitespace from actual string" do
    assert_dom_equal @html_only, @html_with_meaningless_whitespace
  end
  
  test "assert_dom_equal strips meaningless whitespace from both expected and actual strings" do
    assert_dom_equal @more_html_with_meaningless_whitespace, @html_with_meaningless_whitespace
  end
  
  test "assert_dom_not_equal strips meaningless whitespace from expected string" do
    assert_assertion_fails { assert_dom_not_equal @html_with_meaningless_whitespace, @html_only }
  end
  
  test "assert_dom_not_equal strips meaningless whitespace from actual string" do
    assert_assertion_fails { assert_dom_not_equal @html_only, @html_with_meaningless_whitespace }
  end
  
  test "assert_dom_not_equal strips meaningless whitespace from both expected and actual strings" do
    assert_assertion_fails do
      assert_dom_not_equal @more_html_with_meaningless_whitespace, @html_with_meaningless_whitespace
    end
  end
  
  private
  
  def assert_assertion_fails
    assert_raise(Test::Unit::AssertionFailedError) { yield }
  end
end