module ActiveText
  module HtmlConversion
    extend self

    def node_to_html(node)
      node.to_html(save_with: Nokogiri::XML::Node::SaveOptions::AS_HTML)
    end

    def fragment_for_html(html)
      document.fragment(html)
    end

    def create_element(tag_name, attributes = {})
      document.create_element(tag_name, attributes)
    end

    private
      def document
        Nokogiri::HTML::Document.new.tap { |doc| doc.encoding = "UTF-8" }
      end
  end
end
