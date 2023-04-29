# frozen_string_literal: true

module ActiveSupport
  module Cache
    module SerializerWithFallback # :nodoc:
      def self.[](format)
        if format.to_s.include?("message_pack") && !defined?(ActiveSupport::MessagePack)
          require "active_support/message_pack"
        end

        SERIALIZERS.fetch(format)
      end

      def dump_compressed(entry, threshold)
        dumped = dump(entry)
        try_compress(dumped, threshold) || dumped
      end

      def load(dumped)
        if dumped.is_a?(String)
          dumped = decompress(dumped) if compressed?(dumped)

          case
          when MessagePackWithFallback.dumped?(dumped)
            MessagePackWithFallback._load(dumped)
          when Marshal70WithFallback.dumped?(dumped)
            Marshal70WithFallback._load(dumped)
          when Marshal61WithFallback.dumped?(dumped)
            Marshal61WithFallback._load(dumped)
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
        ZLIB_HEADER = "\x78".b.freeze

        def compressed?(dumped)
          dumped.start_with?(ZLIB_HEADER)
        end

        def compress(dumped)
          Zlib::Deflate.deflate(dumped)
        end

        def try_compress(dumped, threshold)
          if dumped.bytesize >= threshold
            compressed = compress(dumped)
            compressed unless compressed.bytesize >= dumped.bytesize
          end
        end

        def decompress(compressed)
          Zlib::Inflate.inflate(compressed)
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

        module Marshal61WithFallback
          include SerializerWithFallback
          extend self

          MARSHAL_SIGNATURE = "\x04\x08".b.freeze

          def dump(entry)
            Marshal.dump(entry)
          end

          def dump_compressed(entry, threshold)
            Marshal.dump(entry.compressed(threshold))
          end

          def _load(dumped)
            Marshal.load(dumped)
          end

          def dumped?(dumped)
            dumped.start_with?(MARSHAL_SIGNATURE)
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
            if compressed = try_compress(dumped, threshold)
              MARK_COMPRESSED + compressed
            else
              MARK_UNCOMPRESSED + dumped
            end
          end

          def _load(marked)
            dumped = marked.byteslice(1..-1)
            dumped = decompress(dumped) if marked.start_with?(MARK_COMPRESSED)
            Cache::Entry.unpack(Marshal.load(dumped))
          end

          def dumped?(dumped)
            dumped.start_with?(MARK_UNCOMPRESSED, MARK_COMPRESSED)
          end
        end

        module MessagePackWithFallback
          include SerializerWithFallback
          extend self

          def dump(entry)
            ActiveSupport::MessagePack::CacheSerializer.dump(entry.pack)
          end

          def _load(dumped)
            packed = ActiveSupport::MessagePack::CacheSerializer.load(dumped)
            Cache::Entry.unpack(packed) if packed
          end

          def dumped?(dumped)
            available? && ActiveSupport::MessagePack.signature?(dumped)
          end

          private
            def available?
              return @available if defined?(@available)
              require "active_support/message_pack"
              @available = true
            rescue LoadError
              @available = false
            end
        end

        SERIALIZERS = {
          passthrough: PassthroughWithFallback,
          marshal_6_1: Marshal61WithFallback,
          marshal_7_0: Marshal70WithFallback,
          message_pack: MessagePackWithFallback,
        }
    end
  end
end
