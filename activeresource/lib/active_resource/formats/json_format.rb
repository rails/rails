module ActiveResource
  module Formats
    module JsonFormat
      extend self
      
      def extension
        "json"
      end
      
      def mime_type
        "application/json"
      end
      
      def encode(hash)
        hash.to_json
      end
      
      def decode(json)
        ActiveSupport::JSON.decode(json)
      end
    end
  end
end