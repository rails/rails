module ActiveSupport
  module Cache
    class CompressedMemCacheStore < MemCacheStore
      def read(name, options = {})
        if value = super(name, options.merge(:raw => true))
          Marshal.load(ActiveSupport::Gzip.decompress(value))
        end
      end

      def write(name, value, options = {})
        super(name, ActiveSupport::Gzip.compress(Marshal.dump(value)), options.merge(:raw => true))
      end
    end
  end
end
