require 'active_support/core_ext/hash/conversions'

module ActiveResource
  module Formats
    module XmlFormat
      extend self

      def extension
        "xml"
      end

      def mime_type
        "application/xml"
      end

      def encode(hash, options={})
        hash.to_xml(options)
      end

      def decode(xml)
        from_xml_data(Hash.from_xml(xml))
      end

      private
        # Manipulate from_xml Hash, because xml_simple is not exactly what we
        # want for Active Resource.
        def from_xml_data(data)
          if data.is_a?(Hash) && data.keys.size == 1
            data.values.first
          else
            data
          end
        end
    end
  end
end
