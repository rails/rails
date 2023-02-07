# frozen_string_literal: true

require "active_support/messages/metadata"

module ActiveSupport
  module Messages # :nodoc:
    class Codec # :nodoc:
      include Metadata

      def initialize(serializer:, url_safe:)
        @serializer =
          case serializer
          when :marshal
            Marshal
          when :hybrid
            JsonWithMarshalFallback
          when :json
            JSON
          else
            serializer
          end

        @url_safe = url_safe
      end

      private
        attr_reader :serializer

        def encode(data, url_safe: @url_safe)
          url_safe ? ::Base64.urlsafe_encode64(data, padding: false) : ::Base64.strict_encode64(data)
        end

        def decode(encoded, url_safe: @url_safe)
          url_safe ? ::Base64.urlsafe_decode64(encoded) : ::Base64.strict_decode64(encoded)
        end

        def serialize(data)
          serializer.dump(data)
        end

        def deserialize(serialized)
          serializer.load(serialized)
        end
    end
  end
end
