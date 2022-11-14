# frozen_string_literal: true

require "json"
require "execjs"

require "rails_guides/search_index_document"

module RailsGuides
  class SearchIndex
    def initialize(guides_dir, output_dir, guides)
      @guides_dir = guides_dir
      @output_dir = output_dir
      @guides = guides.reject { |guide| guide.end_with?(".erb") }
                      .map    { |guide| guide.gsub(".md", ".html") }
    end

    def generate
      documents = @guides.map do |guide|
        generate_documents(guide)
      end.flatten

      generate_index(documents)
    end

    private
      def generate_documents(guide)
        body = File.read(@output_dir + "/" + guide)

        sections = []
        current_section = nil
        heading = nil

        Nokogiri::HTML.fragment(body).tap do |doc|
          puts "Generating search index for #{guide}"
          title = doc.at_css("h2").text

          doc.at_css("#mainCol").children.each do |node|
            case node.name
            when "h3"
              heading = node.text
            when "h4"
              # end previous and start a new section here
              sections << current_section
              link = node.at_css("a")
              next if link.nil?
              anchor = link["href"]
              current_section = SearchIndexDocument.new(guide, anchor, title, heading, node.text)
            when "p"
              current_section = SearchIndexDocument.new(guide, anchor, title, heading, heading) if current_section.nil?
              current_section.append_line(node.text)
            when "div"
              if node.attributes["class"].value == "code_container"
                current_section = SearchIndexDocument.new(guide, anchor, title, heading, heading) if current_section.nil?
                current_section.append_line(node.text)
              end
            end
          end
        end
        sections << current_section
        sections.compact
      end

      def generate_index(documents)
        link_map = {}
        documents.map.each_with_index do |document, index|
          link_map[index] = document.id
          document.id = index
          document
        end

        documents_js = "var lunrDocuments = #{documents.to_json};"
        link_map_js = "var linkMap = #{link_map.to_json};"
        File.write("#{@output_dir}/javascripts/lunr-documents.js", documents_js + link_map_js)

        lunr = File.open("#{@guides_dir}/assets/javascripts/lunr.js").read
        lunr_indexer = File.read("#{@guides_dir}/rails_guides/lunr-indexer.js")
        lunr_index = ExecJS.eval("(function() {" + lunr + documents_js + lunr_indexer + "})()")
        file_content = "var lunrIndexData = #{lunr_index};"
        File.write("#{@output_dir}/javascripts/lunr-index.js", file_content)
      end
  end
end
