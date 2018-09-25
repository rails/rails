# frozen_string_literal: true

module ERBTest
  class ViewContext
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::JavaScriptHelper
    include ActionView::Helpers::FormHelper

    attr_accessor :output_buffer, :controller

    def protect_against_forgery?() false end
  end

  class BlockTestCase < ActiveSupport::TestCase
    def render_content(start, inside, routes = nil)
      routes ||= ActionDispatch::Routing::RouteSet.new.tap do |rs|
        rs.draw {}
      end
      context = Class.new(ViewContext) {
        include routes.url_helpers
      }.new
      template = block_helper(start, inside)
      ActionView::Template::Handlers::ERB.erb_implementation.new(template).evaluate(context)
    end

    def block_helper(str, rest)
      "<%= #{str} do %>#{rest}<% end %>"
    end
  end
end
