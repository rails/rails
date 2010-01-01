require 'libxml'

# = XmlMini LibXML implementation
module ActiveSupport
  module XmlMini_LibXML #:nodoc:
    extend self

    # Parse an XML Document string into a simple hash using libxml.
    # string::
    #   XML Document string to parse
    def parse(string)
      if string.blank?
        {}
      else
        LibXML::XML::Parser.string(string.strip).parse.to_hash
      end
    end
  end
end

module LibXML
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
      def to_hash(hash={})
        node_hash = {}

        # Insert node hash into parent hash correctly.
        case hash[name]
          when Array then hash[name] << node_hash
          when Hash  then hash[name] = [hash[name], node_hash]
          when nil   then hash[name] = node_hash
          else raise "Unexpected error during hash insertion!"
        end

        # Handle child elements
        each_child do |c|
          if c.element?
            c.to_hash(node_hash)
          elsif c.text? || c.cdata?
            node_hash[CONTENT_ROOT] ||= ''
            node_hash[CONTENT_ROOT] << c.content
          end
        end


        # Remove content node if it is blank
        if node_hash.length > 1 && node_hash[CONTENT_ROOT].blank?
          node_hash.delete(CONTENT_ROOT)
        end

        # Handle attributes
        each_attr { |a| node_hash[a.name] = a.value }

        hash
      end
    end
  end
end

LibXML::XML::Document.send(:include, LibXML::Conversions::Document)
LibXML::XML::Node.send(:include, LibXML::Conversions::Node)
