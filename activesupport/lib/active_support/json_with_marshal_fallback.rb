# frozen_string_literal: true

module ActiveSupport
  class JsonWithMarshalFallback
    MARSHAL_SIGNATURE = "\x04\x08"

    cattr_accessor :fallback_to_marshal_deserialization, instance_accessor: false, default: true
    cattr_accessor :use_marshal_serialization, instance_accessor: false, default: true

    class << self
      def logger
        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger
        else
          nil
        end
      end

      def dump(value)
        if self.use_marshal_serialization
          Marshal.dump(value)
        else
          JSON.encode(value)
        end
      end

      def load(value)
        if self.fallback_to_marshal_deserialization
          if value.start_with?(MARSHAL_SIGNATURE)
            logger.warn("JsonWithMarshalFallback: Marshal load fallback occurred.") if logger
            Marshal.load(value)
          else
            JSON.decode(value)
          end
        else
          raise ::JSON::ParserError if value.start_with?(MARSHAL_SIGNATURE)
          JSON.decode(value)
        end
      end
    end
  end
end
