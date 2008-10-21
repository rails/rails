module ActiveSupport
  module Cache
    class CompressedMemCacheStore < MemCacheStore
      def read(name, options = nil)
        if value = super(name, (options || {}).merge(:raw => true))
          if raw?(options)
            value
          else
            Marshal.load(ActiveSupport::Gzip.decompress(value))
          end
        end
      end

      def write(name, value, options = nil)
        value = ActiveSupport::Gzip.compress(Marshal.dump(value)) unless raw?(options)
        super(name, value, (options || {}).merge(:raw => true))
      end
    end
  end
end
