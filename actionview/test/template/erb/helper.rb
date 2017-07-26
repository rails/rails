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
      # IMMUNIO: Modified to render through the entire stack, otherwise you break our ActionView plugins
      # ActionView::Template::Handlers::ERB.erb_implementation.new(template).evaluate(ViewContext.new)

      av_template = ActionView::Template.new(
        template,
        'partial',
        ActionView::Template::Handlers::ERB.new,
        virtual_path: 'partial')

      av_template.render(ViewContext.new, {})
    end

    def block_helper(str, rest)
      "<%= #{str} do %>#{rest}<% end %>"
    end
  end
end
