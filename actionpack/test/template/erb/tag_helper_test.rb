require "abstract_unit"
require "template/erb/helper"

module ERBTest
  module SharedTagHelpers
    extend ActiveSupport::Testing::Declarative

    def maybe_deprecated
      if @deprecated
        assert_deprecated { yield }
      else
        yield
      end
    end

    test "percent equals works for content_tag and does not require parenthesis on method call" do
      maybe_deprecated { assert_equal "<div>Hello world</div>", render_content("content_tag :div", "Hello world") }
    end

    test "percent equals works for javascript_tag" do
      expected_output = "<script type=\"text/javascript\">\n//<![CDATA[\nalert('Hello')\n//]]>\n</script>"
      maybe_deprecated { assert_equal expected_output, render_content("javascript_tag", "alert('Hello')") }
    end

    test "percent equals works for javascript_tag with options" do
      expected_output = "<script id=\"the_js_tag\" type=\"text/javascript\">\n//<![CDATA[\nalert('Hello')\n//]]>\n</script>"
      maybe_deprecated { assert_equal expected_output, render_content("javascript_tag(:id => 'the_js_tag')", "alert('Hello')") }
    end

    test "percent equals works with form tags" do
      expected_output = %r{<form.*action="foo".*method="post">.*hello*</form>}
      maybe_deprecated { assert_match expected_output, render_content("form_tag('foo')", "<%= 'hello' %>") }
    end

    test "percent equals works with fieldset tags" do
      expected_output = "<fieldset><legend>foo</legend>hello</fieldset>"
      maybe_deprecated { assert_equal expected_output, render_content("field_set_tag('foo')", "<%= 'hello' %>") }
    end
  end

  class TagHelperTest < BlockTestCase
    def block_helper(str, rest)
      "<%= #{str} do %>#{rest}<% end %>"
    end

    include SharedTagHelpers
  end

  class DeprecatedTagHelperTest < BlockTestCase
    def block_helper(str, rest)
      "<% __in_erb_template=true %><% #{str} do %>#{rest}<% end %>"
    end

    def setup
      @deprecated = true
    end

    include SharedTagHelpers
  end
end