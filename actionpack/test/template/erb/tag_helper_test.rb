require "abstract_unit"

module ERBTest
  class ViewContext
    mock_controller = Class.new do
      include SharedTestRoutes.url_helpers
    end

    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::JavaScriptHelper
    include ActionView::Helpers::FormHelper

    attr_accessor :output_buffer

    def protect_against_forgery?() false end

    define_method(:controller) do
      mock_controller.new
    end
  end

  class DeprecatedViewContext < ViewContext
    include ActionView::Helpers::DeprecatedBlockHelpers
  end

  module SharedTagHelpers
    extend ActiveSupport::Testing::Declarative

    def render_content(start, inside)
      template = block_helper(start, inside)
      ActionView::Template::Handlers::Erubis.new(template).evaluate(context.new)
    end

    test "percent equals works for content_tag and does not require parenthesis on method call" do
      assert_equal "<div>Hello world</div>", render_content("content_tag :div", "Hello world")
    end

    test "percent equals works for javascript_tag" do
      expected_output = "<script type=\"text/javascript\">\n//<![CDATA[\nalert('Hello')\n//]]>\n</script>"
      assert_equal expected_output, render_content("javascript_tag", "alert('Hello')")
    end

    test "percent equals works for javascript_tag with options" do
      expected_output = "<script id=\"the_js_tag\" type=\"text/javascript\">\n//<![CDATA[\nalert('Hello')\n//]]>\n</script>"
      assert_equal expected_output, render_content("javascript_tag(:id => 'the_js_tag')", "alert('Hello')")
    end

    test "percent equals works with form tags" do
      expected_output = "<form action=\"foo\" method=\"post\">hello</form>"
      assert_equal expected_output, render_content("form_tag('foo')", "<%= 'hello' %>")
    end

    test "percent equals works with fieldset tags" do
      expected_output = "<fieldset><legend>foo</legend>hello</fieldset>"
      assert_equal expected_output, render_content("field_set_tag('foo')", "<%= 'hello' %>")
    end
  end

  class TagHelperTest < ActiveSupport::TestCase
    def context
      ViewContext
    end

    def block_helper(str, rest)
      "<%= #{str} do %>#{rest}<% end %>"
    end

    include SharedTagHelpers
  end

  class DeprecatedTagHelperTest < ActiveSupport::TestCase
    def context
      DeprecatedViewContext
    end

    def block_helper(str, rest)
      "<% __in_erb_template=true %><% #{str} do %>#{rest}<% end %>"
    end

    include SharedTagHelpers
  end
end