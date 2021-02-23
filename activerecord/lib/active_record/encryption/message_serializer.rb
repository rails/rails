module ActiveRecord
  module Encryption
    # A message serializer that serializes +Messages+ with JSON.
    #
    # The generated structure is pretty simple:
    #
    #   {
    #     p: <payload>,
    #     h: {
    #       header1: value1,
    #       header2: value2,
    #       ...
    #     }
    #   }
    #
    # Both the payload and the header values are encoded with Base64
    # to prevent JSON parsing errors and encoding issues when
    # storing the resulting serialized data.
    class MessageSerializer
      def load(serialized_content)
        data = JSON.parse(serialized_content)
        parse_message(data, 1)
      rescue JSON::ParserError
        raise ActiveRecord::Encryption::Errors::Encoding
      end

      def dump(message)
        raise ActiveRecord::Encryption::Errors::ForbiddenClass unless message.is_a?(ActiveRecord::Encryption::Message)
        JSON.dump message_to_json(message)
      end

      private
        def parse_message(data, level)
          raise ActiveRecord::Encryption::Errors::Decryption, "More than one level of hash nesting in headers is not supported" if level > 2
          ActiveRecord::Encryption::Message.new(payload: decode_if_needed(data["p"]), headers: parse_properties(data["h"], level))
        end

        def parse_properties(headers, level)
          ActiveRecord::Encryption::Properties.new.tap do |properties|
            headers&.each do |key, value|
              properties[key] = value.is_a?(Hash) ? parse_message(value, level + 1) : decode_if_needed(value)
            end
          end
        end

        def message_to_json(message)
          {
            p: encode_if_needed(message.payload),
            h: headers_to_json(message.headers)
          }
        end

        def headers_to_json(headers)
          headers.collect do |key, value|
            [key, value.is_a?(ActiveRecord::Encryption::Message) ? message_to_json(value) : encode_if_needed(value)]
          end.to_h
        end

        def encode_if_needed(value)
          if value.is_a?(String)
            ::Base64.strict_encode64 value
          else
            value
          end
        end

        def decode_if_needed(value)
          if value.is_a?(String)
            ::Base64.strict_decode64(value)
          else
            value
          end
        rescue ArgumentError, TypeError
          raise Errors::Encoding
        end
    end
  end
end