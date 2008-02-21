require 'memcache'

module ActiveSupport
  module Cache
    class MemCacheStore < Store
      module Response
        STORED      = "STORED\r\n"
        NOT_STORED  = "NOT_STORED\r\n"
        EXISTS      = "EXISTS\r\n"
        NOT_FOUND   = "NOT_FOUND\r\n"
        DELETED     = "DELETED\r\n"
      end

      attr_reader :addresses

      def initialize(*addresses)
        addresses = addresses.flatten
        addresses = ["localhost"] if addresses.empty?
        @addresses = addresses
        @data = MemCache.new(addresses)
      end

      def read(key, options = nil)
        super
        @data.get(key, raw?(options))
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        nil
      end

      # Set key = value if key isn't already set. Pass :force => true
      # to unconditionally set key = value. Returns a boolean indicating
      # whether the key was set.
      def write(key, value, options = nil)
        super
        method = options && options[:force] ? :set : :add
        response = @data.send(method, key, value, expires_in(options), raw?(options))
        response == Response::STORED
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        false
      end

      def delete(key, options = nil)
        super
        response = @data.delete(key, expires_in(options))
        response == Response::DELETED
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        false
      end

      def delete_matched(matcher, options = nil)
        super
        raise "Not supported by Memcache"
      end

      def clear
        @data.flush_all
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
