# frozen_string_literal: true

require_relative "entry"

module ActiveSupport
  module Cache
    class Coder # :nodoc:
      def initialize(serializer, compressor, legacy_serializer: false)
        @serializer = serializer
        @compressor = compressor
        @legacy_serializer = legacy_serializer
      end

      def dump(entry)
        return @serializer.dump(entry) if @legacy_serializer

        dump_compressed(entry, Float::INFINITY)
      end

      def dump_compressed(entry, threshold)
        return @serializer.dump_compressed(entry, threshold) if @legacy_serializer

        # If value is a string with a supported encoding, use it as the payload
        # instead of passing it through the serializer.
        if type = type_for_string(entry.value)
          payload = entry.value.b
        else
          type = OBJECT_DUMP_TYPE
          payload = @serializer.dump(entry.value)
        end

        if compressed = try_compress(payload, threshold)
          payload = compressed
          type = type | COMPRESSED_FLAG
        end

        expires_at = entry.expires_at || -1.0

        version = dump_version(entry.version) if entry.version
        version_length = version&.bytesize || -1

        packed = SIGNATURE.b
        packed << [type, expires_at, version_length].pack(PACKED_TEMPLATE)
        packed << version if version
        packed << payload
      end

      def load(dumped)
        return @serializer.load(dumped) if !signature?(dumped)

        type = dumped.unpack1(PACKED_TYPE_TEMPLATE)
        expires_at = dumped.unpack1(PACKED_EXPIRES_AT_TEMPLATE)
        version_length = dumped.unpack1(PACKED_VERSION_LENGTH_TEMPLATE)

        expires_at = nil if expires_at < 0
        version = load_version(dumped.byteslice(PACKED_VERSION_INDEX, version_length)) if version_length >= 0
        payload = dumped.byteslice((PACKED_VERSION_INDEX + [version_length, 0].max)..)

        compressor = @compressor if type & COMPRESSED_FLAG > 0
        serializer = STRING_DESERIALIZERS[type & ~COMPRESSED_FLAG] || @serializer

        LazyEntry.new(serializer, compressor, payload, version: version, expires_at: expires_at)
      end

      private
        SIGNATURE = "\x00\x11".b.freeze

        OBJECT_DUMP_TYPE = 0x01

        STRING_ENCODINGS = {
          0x02 => Encoding::UTF_8,
          0x03 => Encoding::BINARY,
          0x04 => Encoding::US_ASCII,
        }

        COMPRESSED_FLAG = 0x80

        PACKED_TEMPLATE = "CEl<"
        PACKED_TYPE_TEMPLATE = "@#{SIGNATURE.bytesize}C"
        PACKED_EXPIRES_AT_TEMPLATE = "@#{[0].pack(PACKED_TYPE_TEMPLATE).bytesize}E"
        PACKED_VERSION_LENGTH_TEMPLATE = "@#{[0].pack(PACKED_EXPIRES_AT_TEMPLATE).bytesize}l<"
        PACKED_VERSION_INDEX = [0].pack(PACKED_VERSION_LENGTH_TEMPLATE).bytesize

        MARSHAL_SIGNATURE = "\x04\x08".b.freeze

        class StringDeserializer
          def initialize(encoding)
            @encoding = encoding
          end

          def load(payload)
            payload.force_encoding(@encoding)
          end
        end

        STRING_DESERIALIZERS = STRING_ENCODINGS.transform_values { |encoding| StringDeserializer.new(encoding) }

        class LazyEntry < Cache::Entry
          def initialize(serializer, compressor, payload, **options)
            super(payload, **options)
            @serializer = serializer
            @compressor = compressor
            @resolved = false
          end

          def value
            if !@resolved
              @value = @serializer.load(@compressor ? @compressor.inflate(@value) : @value)
              @resolved = true
            end
            @value
          end

          def mismatched?(version)
            super.tap { |mismatched| value if !mismatched }
          rescue Cache::DeserializationError
            true
          end
        end

        def signature?(dumped)
          dumped.is_a?(String) && dumped.start_with?(SIGNATURE)
        end

        def type_for_string(value)
          STRING_ENCODINGS.key(value.encoding) if value.instance_of?(String)
        end

        def try_compress(string, threshold)
          if @compressor && string.bytesize >= threshold
            compressed = @compressor.deflate(string)
            compressed if compressed.bytesize < string.bytesize
          end
        end

        def dump_version(version)
          if version.encoding != Encoding::UTF_8 || version.start_with?(MARSHAL_SIGNATURE)
            Marshal.dump(version)
          else
            version.b
          end
        end

        def load_version(dumped_version)
          if dumped_version.start_with?(MARSHAL_SIGNATURE)
            Marshal.load(dumped_version)
          else
            dumped_version.force_encoding(Encoding::UTF_8)
          end
        end
    end
  end
end
