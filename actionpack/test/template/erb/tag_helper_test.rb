require "abstract_unit"

module ERBTest
  module SharedTagHelpers
    extend ActiveSupport::Testing::Declarative

    def render_content(start, inside)
      template = block_helper(start, inside)
      ActionView::Template::Handlers::Erubis.new(template).evaluate(context.new)
    end

    test "percent equals works for content_tag" do
      assert_equal "<div>Hello world</div>", render_content("content_tag(:div)", "Hello world")
    end

    test "percent equals works for javascript_tag" do
      expected_output = "<script type=\"text/javascript\">\n//<![CDATA[\nalert('Hello')\n//]]>\n</script>"
      assert_equal expected_output, render_content("javascript_tag", "alert('Hello')")
    end

    test "percent equals works for javascript_tag with options" do
      expected_output = "<script id=\"the_js_tag\" type=\"text/javascript\">\n//<![CDATA[\nalert('Hello')\n//]]>\n</script>"
      assert_equal expected_output, render_content("javascript_tag(:id => 'the_js_tag')", "alert('Hello')")
    end
  end

  class TagHelperTest < ActiveSupport::TestCase
    def context
      Class.new do
        include ActionView::Helpers::TagHelper
        include ActionView::Helpers::JavaScriptHelper

        attr_accessor :output_buffer
      end
    end

    def block_helper(str, rest)
      "<%= #{str} do %>#{rest}<% end %>"
    end

    include SharedTagHelpers
  end

  class DeprecatedTagHelperTest < ActiveSupport::TestCase
    def context
      Class.new do
        include ActionView::Helpers::TagHelper
        include ActionView::Helpers::JavaScriptHelper
        include ActionView::Helpers::DeprecatedBlockHelpers
        attr_accessor :output_buffer
      end
    end

    def block_helper(str, rest)
      "<% __in_erb_template=true %><% #{str} do %>#{rest}<% end %>"
    end

    include SharedTagHelpers
  end
end