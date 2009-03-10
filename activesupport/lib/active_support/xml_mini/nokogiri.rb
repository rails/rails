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
        Nokogiri::XML(string).to_hash
      end
    end

    module Conversions
      module Document
        def to_hash
          root.to_hash
        end
      end

      module Node
        CONTENT_ROOT = '__content__'

        # Convert XML document to hash
        #
        # hash::
        #   Hash to merge the converted element into.
        def to_hash(hash = {})
          hash[name] ||= attributes_as_hash

          walker = lambda { |child, memo, callback|
            next if child.blank?

            if child.text?
              (memo[CONTENT_ROOT] ||= '') << child.content
              next
            end

            name = child.name

            if memo[name]
              memo[name] = [memo[name]].flatten
              memo[name] << child.attributes_as_hash
            else
              memo[name] = child.attributes_as_hash
            end

            # Recusively walk children
            child.children.each { |c| callback.call(c, memo[name], callback) }
          }

          children.each { |c| walker.call(c, hash[name], walker) }
          hash
        end

        def attributes_as_hash
          Hash[*(attribute_nodes.map { |node|
            [node.node_name, node.value]
          }.flatten)]
        end
      end
    end

    Nokogiri::XML::Document.send(:include, Conversions::Document)
    Nokogiri::XML::Node.send(:include, Conversions::Node)
  end
end
