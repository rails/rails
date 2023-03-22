# frozen_string_literal: true

require_relative "serializer"

module ActiveSupport
  module MessagePack
    module CacheSerializer
      include Serializer
      extend self

      ZLIB_HEADER = "\x78"

      def dump(entry)
        super(entry.pack)
      end

      def dump_compressed(entry, threshold) # :nodoc:
        dumped = dump(entry)
        if dumped.bytesize >= threshold
          compressed = Zlib::Deflate.deflate(dumped)
          compressed.bytesize < dumped.bytesize ? compressed : dumped
        else
          dumped
        end
      end

      def load(dumped)
        dumped = Zlib::Inflate.inflate(dumped) if compressed?(dumped)
        ActiveSupport::Cache::Entry.unpack(super)
      rescue ActiveSupport::MessagePack::MissingClassError
        # Treat missing class as cache miss => return nil
      end

      private
        def compressed?(dumped)
          dumped.start_with?(ZLIB_HEADER)
        end

        def install_unregistered_type_handler
          Extensions.install_unregistered_type_fallback(message_pack_factory)
        end
    end
  end
end
