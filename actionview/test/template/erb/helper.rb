module ERBTest
  class ViewContext
    include ActionView::Helpers::UrlHelper
    include SharedTestRoutes.url_helpers
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::JavaScriptHelper
    include ActionView::Helpers::FormHelper

    attr_accessor :output_buffer, :controller

    def protect_against_forgery?() false end
  end

  class BlockTestCase < ActiveSupport::TestCase
    def render_content(start, inside)
      template = block_helper(start, inside)
      ActionView::Template::Handlers::ERB.erb_implementation.new(template).evaluate(ViewContext.new)
    end

    def block_helper(str, rest)
      "<%= #{str} do %>#{rest}<% end %>"
    end
  end
end
