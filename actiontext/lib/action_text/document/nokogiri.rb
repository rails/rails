# frozen_string_literal: true

require "nokogiri"
require "action_text/document/nokogiri/plain_text_conversion"

module ActionText
  module Document
    module Nokogiri
      extend self

      def is_fragment?(node)
        node.respond_to?(:fragment?) && node.fragment?
      end

      def is_whitespace?(node)
        if node.text?
          /\A(\n|\ )*\z/.match?(node.text)
        end
      end

      def fragment_for_html(html)
        document.fragment(html)
      end

      def clone_node(node)
        node.clone
      end

      def node_to_html(node)
        node.to_html(save_with: ::Nokogiri::XML::Node::SaveOptions::AS_HTML)
      end

      def node_to_text(node)
        PlainTextConversion.node_to_plain_text(node)
      end

      def text_content(node)
        node.text
      end

      def node_attribute(node, attr_name)
        node[attr_name]
      end

      def node_children(node)
        node.children
      end

      def node_matches?(node, css_selector)
        node.matches?(css_selector)
      end

      def find(node, css_selector)
        node.css(css_selector)
      end

      # returns the node; if the model is immutable, it might return a
      # clone of the node instead, with the children removed as requested.
      def remove_children(node)
        node.tap { |n| n.inner_html = "" }
      end

      def create_element(tag_name, attributes = {})
        document.create_element(tag_name, attributes)
      end

      # either returns a new node, or an HTML string representing the new
      # node, with the new name, and all attributes removed.
      def canonicalize_node(node, name)
        "<#{name}>#{node.inner_html}</#{name}>"
      end

      # returns the replaced node. It may be `node` mutated in place, or
      # a new node instance.
      def replace_node(node, replacement)
        node.replace(replacement.to_s)
      end

      private
        def document
          ::Nokogiri::HTML::Document.new.tap { |doc| doc.encoding = "UTF-8" }
        end
    end
  end
end
