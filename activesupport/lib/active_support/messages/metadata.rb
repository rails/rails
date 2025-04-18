# frozen_string_literal: true

require "time"
require "active_support/json"
require_relative "serializer_with_fallback"

module ActiveSupport
  module Messages # :nodoc:
    module Metadata # :nodoc:
      singleton_class.attr_accessor :use_message_serializer_for_metadata

      ENVELOPE_SERIALIZERS = [
        *SerializerWithFallback::SERIALIZERS.values,
        ActiveSupport::JSON,
        ::JSON,
        Marshal,
      ]

      TIMESTAMP_SERIALIZERS = [
        SerializerWithFallback::SERIALIZERS.fetch(:message_pack),
        SerializerWithFallback::SERIALIZERS.fetch(:message_pack_allow_marshal),
      ]

      ActiveSupport.on_load(:message_pack) do
        ENVELOPE_SERIALIZERS << ActiveSupport::MessagePack
        TIMESTAMP_SERIALIZERS << ActiveSupport::MessagePack
      end

      private
        def serialize_with_metadata(data, **metadata)
          has_metadata = metadata.any? { |k, v| v }

          if has_metadata && !use_message_serializer_for_metadata?
            data_string = serialize_to_json_safe_string(data)
            envelope = wrap_in_metadata_legacy_envelope({ "message" => data_string }, **metadata)
            serialize_to_json(envelope)
          else
            data = wrap_in_metadata_envelope({ "data" => data }, **metadata) if has_metadata
            serialize(data)
          end
        end

        def deserialize_with_metadata(message, **expected_metadata)
          if dual_serialized_metadata_envelope_json?(message)
            envelope = deserialize_from_json(message)
            extracted = extract_from_metadata_envelope(envelope, **expected_metadata)
            deserialize_from_json_safe_string(extracted["message"])
          else
            deserialized = deserialize(message)
            if metadata_envelope?(deserialized)
              extract_from_metadata_envelope(deserialized, **expected_metadata)["data"]
            elsif expected_metadata.none? { |k, v| v }
              deserialized
            else
              throw :invalid_message_content, "missing metadata"
            end
          end
        end

        def use_message_serializer_for_metadata?
          Metadata.use_message_serializer_for_metadata && Metadata::ENVELOPE_SERIALIZERS.include?(serializer)
        end

        def wrap_in_metadata_envelope(hash, expires_at: nil, expires_in: nil, purpose: nil)
          expiry = pick_expiry(expires_at, expires_in)
          hash["exp"] = expiry if expiry
          hash["pur"] = purpose.to_s if purpose
          { "_rails" => hash }
        end

        def wrap_in_metadata_legacy_envelope(hash, expires_at: nil, expires_in: nil, purpose: nil)
          expiry = pick_expiry(expires_at, expires_in)
          hash["exp"] = expiry
          hash["pur"] = purpose
          { "_rails" => hash }
        end

        def extract_from_metadata_envelope(envelope, purpose: nil)
          hash = envelope["_rails"]

          if hash["exp"] && Time.now.utc >= parse_expiry(hash["exp"])
            throw :invalid_message_content, "expired"
          end

          if hash["pur"].to_s != purpose.to_s
            throw :invalid_message_content, "mismatched purpose"
          end

          hash
        end

        def metadata_envelope?(object)
          object.is_a?(Hash) && object.key?("_rails")
        end

        def dual_serialized_metadata_envelope_json?(string)
          string.start_with?('{"_rails":{"message":')
        end

        def pick_expiry(expires_at, expires_in)
          expiry = if expires_at
            expires_at.utc
          elsif expires_in
            Time.now.utc.advance(seconds: expires_in)
          end

          unless Metadata::TIMESTAMP_SERIALIZERS.include?(serializer)
            expiry = expiry&.iso8601(3)
          end

          expiry
        end

        def parse_expiry(expires_at)
          if !expires_at.is_a?(String)
            expires_at
          elsif ActiveSupport.use_standard_json_time_format
            Time.iso8601(expires_at)
          else
            Time.parse(expires_at)
          end
        end

        def serialize_to_json(data)
          ActiveSupport::JSON.encode(data)
        end

        def deserialize_from_json(serialized)
          ActiveSupport::JSON.decode(serialized)
        rescue ::JSON::ParserError => error
          # Throw :invalid_message_format instead of :invalid_message_serialization
          # because here a parse error is due to a bad message rather than an
          # incompatible `self.serializer`.
          throw :invalid_message_format, error
        end

        def serialize_to_json_safe_string(data)
          encode(serialize(data), url_safe: false)
        end

        def deserialize_from_json_safe_string(string)
          deserialize(decode(string, url_safe: false))
        end
    end
  end
end
