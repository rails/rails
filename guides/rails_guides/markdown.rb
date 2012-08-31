require 'redcarpet'
require 'nokogiri'
require 'rails_guides/markdown/renderer'

module RailsGuides
  class Markdown
    def initialize(view, layout)
      @view = view
      @layout = layout
    end

    def render(body)
      @header, _, @body = body.partition(/^\-{40,}$/)
      render_header
      render_body
    end

    private
      def engine
        @engine ||= Redcarpet::Markdown.new(Renderer, {
          no_intra_emphasis: true,
          fenced_code_blocks: true,
          autolink: true,
          strikethrough: true,
          superscript: true
        })
      end

      def render_header
        header_content = engine.render(@header)
        @view.content_for(:header_section) { header_content.html_safe }

        @view.content_for(:page_title) do
          "Ruby on Rails Guides: #{Nokogiri::HTML(header_content).at(:h2).text}".html_safe
        end
      end

      def render_body
        @view.render(:layout => @layout, :text => engine.render(@body))
      end
  end
end
