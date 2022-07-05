# frozen_string_literal: true

module ActionText
  module HtmlConversion
    extend self

    %i[ node_to_html fragment_for_html :create_element ].each do |method|
      deprecate method => "use ActionText::Document\##{method} instead"
    end

    def node_to_html(node)
      ActionText::Document.node_to_html(node)
    end

    def fragment_for_html(html)
      ActionText::Document.fragment_for_html(html)
    end

    def create_element(tag_name, attributes = {})
      ActionText::Document.create_element(tag_name, attributes)
    end
  end
end
