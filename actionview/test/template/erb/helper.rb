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
    class Context < ActionView::Base
    end

    def render_content(start, inside, routes = nil)
      routes ||= ActionDispatch::Routing::RouteSet.new.tap do |rs|
        rs.draw { }
      end

      view = Class.new(Context)
      view.include routes.url_helpers

      ActionView::Template.new(
        block_helper(start, inside),
        "test#{rand}",
        ActionView::Template::Handlers::ERB.new,
        virtual_path: "partial",
        format: :html,
        locals: []
      ).render(view.with_empty_template_cache.empty, {})
    end

    def block_helper(str, rest)
      "<%= #{str} do %>#{rest}<% end %>"
    end
  end
end
