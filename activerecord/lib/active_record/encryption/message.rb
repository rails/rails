module ActiveRecord
  module Encryption
    # A message defines the structure of the data we store in encrypted attributes. It contains:
    #
    # * An encrypted payload
    # * A list of unencrypted headers
    #
    # See +Encryptor#encrypt+
    class Message
      attr_accessor :payload, :headers

      def initialize(payload: nil, headers: {})
        validate_payload_type(payload)

        @payload = payload
        @headers = Properties.new(headers)
      end

      def ==(other_message)
        payload == other_message.payload && headers == other_message.headers
      end

      private
        def validate_payload_type(payload)
          unless payload.is_a?(String) || payload.nil?
            raise ActiveRecord::Encryption::Errors::ForbiddenClass, "Only string payloads allowed"
          end
        end
    end
  end
end
