# frozen_string_literal: true

require "active_support/messages/metadata"

module ActiveSupport
  module Messages # :nodoc:
    class Codec # :nodoc:
      include Metadata

      def initialize(serializer:, url_safe:, force_legacy_metadata_serializer: false)
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
        @force_legacy_metadata_serializer = force_legacy_metadata_serializer
      end

      private
        attr_reader :serializer

        def encode(data, url_safe: @url_safe)
          url_safe ? ::Base64.urlsafe_encode64(data, padding: false) : ::Base64.strict_encode64(data)
        end

        def decode(encoded, url_safe: @url_safe)
          url_safe ? ::Base64.urlsafe_decode64(encoded) : ::Base64.strict_decode64(encoded)
        rescue ArgumentError => error
          throw :invalid_message_format, error
        end

        def serialize(data)
          serializer.dump(data)
        end

        def deserialize(serialized)
          serializer.load(serialized)
        rescue StandardError => error
          throw :invalid_message_serialization, error
        end

        def catch_and_ignore(throwable, &block)
          catch throwable do
            return block.call
          end
          nil
        end

        def catch_and_raise(throwable, as: nil, &block)
          error = catch throwable do
            return block.call
          end
          error = as.new(error.to_s) if as
          raise error
        end

        def use_message_serializer_for_metadata?
          !@force_legacy_metadata_serializer && super
        end
    end
  end
end
