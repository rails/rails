# frozen_string_literal: true

require "zlib"
require "active_support/core_ext/kernel/reporting"

module ActiveSupport
  module Cache
    module SerializerWithFallback # :nodoc:
      def self.[](format)
        if format.to_s.include?("message_pack") && !defined?(ActiveSupport::MessagePack)
          require "active_support/message_pack"
        end

        SERIALIZERS.fetch(format)
      end

      def load(dumped)
        if dumped.is_a?(String)
          case
          when MessagePackWithFallback.dumped?(dumped)
            MessagePackWithFallback._load(dumped)
          when Marshal71WithFallback.dumped?(dumped)
            Marshal71WithFallback._load(dumped)
          when Marshal70WithFallback.dumped?(dumped)
            Marshal70WithFallback._load(dumped)
          else
            Cache::Store.logger&.warn("Unrecognized payload prefix #{dumped.byteslice(0).inspect}; deserializing as nil")
            nil
          end
        elsif PassthroughWithFallback.dumped?(dumped)
          PassthroughWithFallback._load(dumped)
        else
          Cache::Store.logger&.warn("Unrecognized payload class #{dumped.class}; deserializing as nil")
          nil
        end
      end

      private
        def marshal_load(payload)
          Marshal.load(payload)
        rescue ArgumentError => error
          raise Cache::DeserializationError, error.message
        end

        module PassthroughWithFallback
          include SerializerWithFallback
          extend self

          def dump(entry)
            entry
          end

          def dump_compressed(entry, threshold)
            entry.compressed(threshold)
          end

          def _load(entry)
            entry
          end

          def dumped?(dumped)
            dumped.is_a?(Cache::Entry)
          end
        end

        module Marshal70WithFallback
          include SerializerWithFallback
          extend self

          MARK_UNCOMPRESSED = "\x00".b.freeze
          MARK_COMPRESSED   = "\x01".b.freeze

          def dump(entry)
            MARK_UNCOMPRESSED + Marshal.dump(entry.pack)
          end

          def dump_compressed(entry, threshold)
            dumped = Marshal.dump(entry.pack)

            if dumped.bytesize >= threshold
              compressed = Zlib::Deflate.deflate(dumped)
              return MARK_COMPRESSED + compressed if compressed.bytesize < dumped.bytesize
            end

            MARK_UNCOMPRESSED + dumped
          end

          def _load(marked)
            dumped = marked.byteslice(1..-1)
            dumped = Zlib::Inflate.inflate(dumped) if marked.start_with?(MARK_COMPRESSED)
            Cache::Entry.unpack(marshal_load(dumped))
          end

          def dumped?(dumped)
            dumped.start_with?(MARK_UNCOMPRESSED, MARK_COMPRESSED)
          end
        end

        module Marshal71WithFallback
          include SerializerWithFallback
          extend self

          MARSHAL_SIGNATURE = "\x04\x08".b.freeze

          def dump(value)
            Marshal.dump(value)
          end

          def _load(dumped)
            marshal_load(dumped)
          end

          def dumped?(dumped)
            dumped.start_with?(MARSHAL_SIGNATURE)
          end
        end

        module MessagePackWithFallback
          include SerializerWithFallback
          extend self

          def dump(value)
            ActiveSupport::MessagePack::CacheSerializer.dump(value)
          end

          def _load(dumped)
            ActiveSupport::MessagePack::CacheSerializer.load(dumped)
          end

          def dumped?(dumped)
            available? && ActiveSupport::MessagePack.signature?(dumped)
          end

          private
            def available?
              return @available if defined?(@available)
              silence_warnings { require "active_support/message_pack" }
              @available = true
            rescue LoadError
              @available = false
            end
        end

        SERIALIZERS = {
          passthrough: PassthroughWithFallback,
          marshal_7_0: Marshal70WithFallback,
          marshal_7_1: Marshal71WithFallback,
          message_pack: MessagePackWithFallback,
        }
    end
  end
end
