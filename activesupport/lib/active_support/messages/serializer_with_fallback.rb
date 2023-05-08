# frozen_string_literal: true

require "active_support/notifications"

module ActiveSupport
  module Messages # :nodoc:
    module SerializerWithFallback # :nodoc:
      def self.[](format)
        SERIALIZERS.fetch(format)
      end

      def load(dumped)
        format = detect_format(dumped)

        if format == self.format
          _load(dumped)
        elsif format && fallback?(format)
          payload = { serializer: SERIALIZERS.key(self), fallback: format, serialized: dumped }
          ActiveSupport::Notifications.instrument("message_serializer_fallback.active_support", payload) do
            payload[:deserialized] = SERIALIZERS[format]._load(dumped)
          end
        else
          raise "Unsupported serialization format"
        end
      end

      private
        def detect_format(dumped)
          case
          when MarshalWithFallback.dumped?(dumped)
            :marshal
          when JsonWithFallback.dumped?(dumped)
            :json
          end
        end

        def fallback?(format)
          format != :marshal
        end

        module AllowMarshal
          private
            def fallback?(format)
              super || format == :marshal
            end
        end

        module MarshalWithFallback
          include SerializerWithFallback
          extend self

          def format
            :marshal
          end

          def dump(object)
            Marshal.dump(object)
          end

          def _load(dumped)
            Marshal.load(dumped)
          end

          MARSHAL_SIGNATURE = "\x04\x08"

          def dumped?(dumped)
            dumped.start_with?(MARSHAL_SIGNATURE)
          end
        end

        module JsonWithFallback
          include SerializerWithFallback
          extend self

          def format
            :json
          end

          def dump(object)
            ActiveSupport::JSON.encode(object)
          end

          def _load(dumped)
            ActiveSupport::JSON.decode(dumped)
          end

          JSON_START_WITH = /\A(?:[{\["]|-?\d|true|false|null)/

          def dumped?(dumped)
            JSON_START_WITH.match?(dumped)
          end

          private
            def detect_format(dumped)
              # Assume JSON format if format could not be determined.
              super || :json
            end
        end

        module JsonWithFallbackAllowMarshal
          include JsonWithFallback
          include AllowMarshal
          extend self
        end

        SERIALIZERS = {
          marshal: MarshalWithFallback,
          json: JsonWithFallback,
          json_allow_marshal: JsonWithFallbackAllowMarshal,
        }
    end
  end
end
