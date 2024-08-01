# frozen_string_literal: true

require "active_support/message_pack"

module ActiveRecord
  module Encryption
    # A message serializer that serializes +Messages+ with MessagePack.
    #
    # The message is converted to a hash with this structure:
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
    # Then it is converted to the MessagePack format.
    class MessagePackMessageSerializer
      def dump(message)
        raise Errors::ForbiddenClass unless message.is_a?(Message)
        ActiveSupport::MessagePack.dump(message_to_hash(message))
      end

      def load(serialized_content)
        data = ActiveSupport::MessagePack.load(serialized_content)
        hash_to_message(data, 1)
      rescue RuntimeError
        raise Errors::Decryption
      end

      def binary?
        true
      end

      private
        def message_to_hash(message)
          {
            "p" => message.payload,
            "h" => headers_to_hash(message.headers)
          }
        end

        def headers_to_hash(headers)
          headers.transform_values do |value|
            value.is_a?(Message) ? message_to_hash(value) : value
          end
        end

        def hash_to_message(data, level)
          validate_message_data_format(data, level)
          Message.new(payload: data["p"], headers: parse_properties(data["h"], level))
        end

        def validate_message_data_format(data, level)
          if level > 2
            raise Errors::Decryption, "More than one level of hash nesting in headers is not supported"
          end

          unless data.is_a?(Hash) && data.has_key?("p")
            raise Errors::Decryption, "Invalid data format: hash without payload"
          end
        end

        def parse_properties(headers, level)
          Properties.new.tap do |properties|
            headers&.each do |key, value|
              properties[key] = value.is_a?(Hash) ? hash_to_message(value, level + 1) : value
            end
          end
        end
    end
  end
end
