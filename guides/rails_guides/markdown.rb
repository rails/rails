require 'redcarpet'
require 'nokogiri'
require 'rails_guides/markdown/renderer'

module RailsGuides
  class Markdown
    def initialize(view, layout)
      @view = view
      @layout = layout
      @index_counter = Hash.new(0)
    end

    def render(body)
      @raw_header, _, @raw_body = body.partition(/^\-{40,}$/).map(&:strip)
      generate_header
      generate_title
      generate_body
      generate_structure
      generate_index
      render_page
    end

    private

      def dom_id(nodes)
        nodes.map{ |node| node[:id] ? node[:id] : node.text.downcase.gsub(/[^a-z0-9]+/, '-') }.join('-')
      end

      def engine
        @engine ||= Redcarpet::Markdown.new(Renderer, {
          no_intra_emphasis: true,
          fenced_code_blocks: true,
          autolink: true,
          strikethrough: true,
          superscript: true
        })
      end

      def generate_body
        @body = engine.render(@raw_body)
      end

      def generate_header
        @header = engine.render(@raw_header).html_safe
      end

      def generate_structure
        @raw_index = ''
        @body = Nokogiri::HTML(@body).tap do |doc|
          hierarchy = []

          doc.at('body').children.each do |node|
            if node.name =~ /^h[3-6]$/
              case node.name
              when 'h3'
                hierarchy = [node]
                node[:id] = dom_id(hierarchy)
                @raw_index += "1. [#{node.text}](##{node[:id]})\n"
              when 'h4'
                hierarchy = hierarchy[0, 1] + [node]
                node[:id] = dom_id(hierarchy)
                @raw_index += "    * [#{node.text}](##{node[:id]})\n"
              when 'h5'
                hierarchy = hierarchy[0, 2] + [node]
                node[:id] = dom_id(hierarchy)
              when 'h6'
                hierarchy = hierarchy[0, 3] + [node]
                node[:id] = dom_id(hierarchy)
              end

              node.inner_html = "#{node_index(hierarchy)} #{node.text}"
            end
          end
        end.to_html
      end

      def generate_index
        @index = Nokogiri::HTML(engine.render(@raw_index)).tap do |doc|
          doc.at('ol')[:class] = 'chapters'
        end.to_html

        @index = <<-INDEX.html_safe
        <div id="subCol">
          <h3 class="chapter"><img src="images/chapters_icon.gif" alt="" />Chapters</h3>
          #{@index}
        </div>
        INDEX
      end

      def generate_title
        @title = "Ruby on Rails Guides: #{Nokogiri::HTML(@header).at(:h2).text}".html_safe
      end

      def node_index(hierarchy)
        case hierarchy.size
        when 1
          @index_counter[2] = @index_counter[3] = @index_counter[4] = 0
          "#{@index_counter[1] += 1}"
        when 2
          @index_counter[3] = @index_counter[4] = 0
          "#{@index_counter[1]}.#{@index_counter[2] += 1}"
        when 3
          @index_counter[4] = 0
          "#{@index_counter[1]}.#{@index_counter[2]}.#{@index_counter[3] += 1}"
        when 4
          "#{@index_counter[1]}.#{@index_counter[2]}.#{@index_counter[3]}.#{@index_counter[4] += 1}"
        end
      end

      def render_page
        @view.content_for(:header_section) { @header }
        @view.content_for(:page_title) { @title }
        @view.content_for(:index_section) { @index.html_safe }
        @view.render(:layout => @layout, :text => @body)
      end
  end
end
