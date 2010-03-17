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

  class BlockTestCase < ActiveSupport::TestCase
    def render_content(start, inside)
      template = block_helper(start, inside)
      ActionView::Template::Handlers::Erubis.new(template).evaluate(ViewContext.new)
    end

    def block_helper(str, rest)
      "<%= #{str} do %>#{rest}<% end %>"
    end
  end
end