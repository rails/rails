module Mime
  class Type
    class << self
      def lookup(string)
        LOOKUP[string]
      end

      def parse(accept_header)
        mime_types = accept_header.split(",").collect! do |mime_type|
          mime_type.split(";").first.strip
        end

        reorder_xml_types!(mime_types)
        mime_types.collect! { |mime_type| Mime::Type.lookup(mime_type) }
      end
      
      private
        def reorder_xml_types!(mime_types)
          mime_types.delete("text/xml") if mime_types.include?("application/xml")

          if index_for_generic_xml = mime_types.index("application/xml")
            specific_xml_types = mime_types[index_for_generic_xml..-1].grep(/application\/[a-z]*\+xml/)

            for specific_xml_type in specific_xml_types.reverse
              mime_types.insert(index_for_generic_xml, mime_types.delete(specific_xml_type))
            end
          end
        end
    end
    
    def initialize(string, symbol = nil, synonyms = [])
      @symbol, @synonyms = symbol, synonyms
      @string = string
    end
    
    def to_s
      @string
    end
    
    def to_str
      to_s
    end
    
    def to_sym
      @symbol || @string.to_sym
    end

    def ===(list)
      if list.is_a?(Array)
        (@synonyms + [ self ]).any? { |synonym| list.include?(synonym) }
      else
        super
      end
    end
    
    def ==(mime_type)
      (@synonyms + [ self ]).any? { |synonym| synonym.to_s == mime_type.to_s } if mime_type
    end
  end

  ALL   = Type.new "*/*", :all
  HTML  = Type.new "text/html", :html, %w( application/xhtml+xml )
  JS    = Type.new "text/javascript", :js, %w( application/javascript application/x-javascript )
  XML   = Type.new "application/xml", :xml, %w( text/xml application/x-xml )
  RSS   = Type.new "application/rss+xml", :rss
  ATOM  = Type.new "application/atom+xml", :atom
  YAML  = Type.new "application/x-yaml", :yaml, %w( text/yaml )

  LOOKUP = Hash.new { |h, k| h[k] = Type.new(k) }

  LOOKUP["*/*"]                      = ALL

  LOOKUP["text/html"]                = HTML
  LOOKUP["application/xhtml+xml"]    = HTML

  LOOKUP["application/xml"]          = XML
  LOOKUP["text/xml"]                 = XML
  LOOKUP["application/x-xml"]        = XML

  LOOKUP["text/javascript"]          = JS
  LOOKUP["application/javascript"]   = JS
  LOOKUP["application/x-javascript"] = JS

  LOOKUP["text/yaml"]                = YAML
  LOOKUP["application/x-yaml"]       = YAML

  LOOKUP["application/rss+xml"]      = RSS
  LOOKUP["application/atom+xml"]     = ATOM
end