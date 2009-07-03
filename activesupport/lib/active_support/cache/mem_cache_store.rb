require 'memcache'

module ActiveSupport
  module Cache
    # A cache store implementation which stores data in Memcached:
    # http://www.danga.com/memcached/
    #
    # This is currently the most popular cache store for production websites.
    #
    # Special features:
    # - Clustering and load balancing. One can specify multiple memcached servers,
    #   and MemCacheStore will load balance between all available servers. If a
    #   server goes down, then MemCacheStore will ignore it until it goes back
    #   online.
    # - Time-based expiry support. See #write and the <tt>:expires_in</tt> option.
    # - Per-request in memory cache for all communication with the MemCache server(s).
    class MemCacheStore < Store
      module Response # :nodoc:
        STORED      = "STORED\r\n"
        NOT_STORED  = "NOT_STORED\r\n"
        EXISTS      = "EXISTS\r\n"
        NOT_FOUND   = "NOT_FOUND\r\n"
        DELETED     = "DELETED\r\n"
      end

      def self.build_mem_cache(*addresses)
        addresses = addresses.flatten
        options = addresses.extract_options!
        addresses = ["localhost"] if addresses.empty?
        MemCache.new(addresses, options)
      end

      # Creates a new MemCacheStore object, with the given memcached server
      # addresses. Each address is either a host name, or a host-with-port string
      # in the form of "host_name:port". For example:
      #
      #   ActiveSupport::Cache::MemCacheStore.new("localhost", "server-downstairs.localnetwork:8229")
      #
      # If no addresses are specified, then MemCacheStore will connect to
      # localhost port 11211 (the default memcached port).
      def initialize(*addresses)
        if addresses.first.respond_to?(:get)
          @data = addresses.first
        else
          @data = self.class.build_mem_cache(*addresses)
        end

        extend Strategy::LocalCache
      end

      # Reads multiple keys from the cache.
      def read_multi(*keys)
        @data.get_multi keys
      end

      def read(key, options = nil) # :nodoc:
        super
        @data.get(key, raw?(options))
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        nil
      end

      # Writes a value to the cache.
      #
      # Possible options:
      # - <tt>:unless_exist</tt> - set to true if you don't want to update the cache
      #   if the key is already set.
      # - <tt>:expires_in</tt> - the number of seconds that this value may stay in
      #   the cache. See ActiveSupport::Cache::Store#write for an example.
      def write(key, value, options = nil)
        super
        method = options && options[:unless_exist] ? :add : :set
        # memcache-client will break the connection if you send it an integer
        # in raw mode, so we convert it to a string to be sure it continues working.
        value = value.to_s if raw?(options)
        response = @data.send(method, key, value, expires_in(options), raw?(options))
        response == Response::STORED
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        false
      end

      def delete(key, options = nil) # :nodoc:
        super
        response = @data.delete(key, expires_in(options))
        response == Response::DELETED
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        false
      end

      def exist?(key, options = nil) # :nodoc:
        # Doesn't call super, cause exist? in memcache is in fact a read
        # But who cares? Reading is very fast anyway
        # Local cache is checked first, if it doesn't know then memcache itself is read from
        !read(key, options).nil?
      end

      def increment(key, amount = 1) # :nodoc:
        log("incrementing", key, amount)

        response = @data.incr(key, amount)
        response == Response::NOT_FOUND ? nil : response
      rescue MemCache::MemCacheError
        nil
      end

      def decrement(key, amount = 1) # :nodoc:
        log("decrement", key, amount)
        response = @data.decr(key, amount)
        response == Response::NOT_FOUND ? nil : response
      rescue MemCache::MemCacheError
        nil
      end

      def delete_matched(matcher, options = nil) # :nodoc:
        # don't do any local caching at present, just pass
        # through and let the error happen
        super
        raise "Not supported by Memcache"
      end

      def clear
        @data.flush_all
      end

      def stats
        @data.stats
      end

      private
        def raw?(options)
          options && options[:raw]
        end
    end
  end
end
