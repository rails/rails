require 'memcache'

module ActiveSupport
  module Cache
    class MemCacheStore < Store
      attr_reader :addresses

      def initialize(*addresses)
        addresses = addresses.flatten
        addresses = ["localhost"] if addresses.empty?
        @addresses = addresses
        @data = MemCache.new(*addresses)
      end

      def read(key, options = nil)
        super
        @data.get(key, raw?(options))
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        nil
      end

      def write(key, value, options = nil)
        super
        @data.set(key, value, expires_in(options), raw?(options))
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        nil
      end

      def delete(key, options = nil)
        super
        @data.delete(key, expires_in(options))
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        nil
      end

      def delete_matched(matcher, options = nil)
        super
        raise "Not supported by Memcache"
      end

      private
        def expires_in(options)
          (options && options[:expires_in]) || 0
        end

        def raw?(options)
          options && options[:raw]
        end
    end
  end
end
