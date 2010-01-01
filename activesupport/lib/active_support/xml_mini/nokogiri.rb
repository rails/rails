require 'nokogiri'

# = XmlMini Nokogiri implementation
module ActiveSupport
  module XmlMini_Nokogiri #:nodoc:
    extend self

    # Parse an XML Document string into a simple hash using libxml / nokogiri.
    # string::
    #   XML Document string to parse
    def parse(string)
      if string.blank?
        {}
      else
        doc = Nokogiri::XML(string)
        raise doc.errors.first if doc.errors.length > 0
        doc.to_hash
      end
    end

    module Conversions
      module Document
        def to_hash
          root.to_hash
        end
      end

      module Node
        CONTENT_ROOT = '__content__'.freeze

        # Convert XML document to hash
        #
        # hash::
        #   Hash to merge the converted element into.
        def to_hash(hash = {})
          node_hash = {}

          # Insert node hash into parent hash correctly.
          case hash[name]
            when Array then hash[name] << node_hash
            when Hash  then hash[name] = [hash[name], node_hash]
            when nil   then hash[name] = node_hash
            else raise "Unexpected error during hash insertion!"
          end

          # Handle child elements
          children.each do |c|
            if c.element?
              c.to_hash(node_hash)
            elsif c.text? || c.cdata?
              node_hash[CONTENT_ROOT] ||= ''
              node_hash[CONTENT_ROOT] << c.content
             end
          end

          # Remove content node if it is blank and there are child tags
          if node_hash.length > 1 && node_hash[CONTENT_ROOT].blank?
            node_hash.delete(CONTENT_ROOT)
          end

          # Handle attributes
          attribute_nodes.each { |a| node_hash[a.node_name] = a.value }

          hash
        end
      end
    end

    Nokogiri::XML::Document.send(:include, Conversions::Document)
    Nokogiri::XML::Node.send(:include, Conversions::Node)
  end
end
