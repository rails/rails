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
    # - Time-based expiry support. See #write and the +:expires_in+ option.
    # - Per-request in memory cache for all communication with the MemCache server(s).
    class MemCacheStore < Store
      module Response # :nodoc:
        STORED      = "STORED\r\n"
        NOT_STORED  = "NOT_STORED\r\n"
        EXISTS      = "EXISTS\r\n"
        NOT_FOUND   = "NOT_FOUND\r\n"
        DELETED     = "DELETED\r\n"
      end

      # this allows caching of the fact that there is nothing in the remote cache
      NULL = 'mem_cache_store:null'

      THREAD_LOCAL_KEY = :mem_cache_store_cache

      class LocalCache
        def initialize(app)
          @app = app
        end

        def call(env)
          Thread.current[THREAD_LOCAL_KEY] = MemoryStore.new
          @app.call(env)
        ensure
          Thread.current[THREAD_LOCAL_KEY] = nil
        end
      end

      attr_reader :addresses

      # Creates a new MemCacheStore object, with the given memcached server
      # addresses. Each address is either a host name, or a host-with-port string
      # in the form of "host_name:port". For example:
      #
      #   ActiveSupport::Cache::MemCacheStore.new("localhost", "server-downstairs.localnetwork:8229")
      #
      # If no addresses are specified, then MemCacheStore will connect to
      # localhost port 11211 (the default memcached port).
      def initialize(*addresses)
        addresses = addresses.flatten
        options = addresses.extract_options!
        addresses = ["localhost"] if addresses.empty?
        @addresses = addresses
        @data = MemCache.new(addresses, options)
      end

      def read(key, options = nil) # :nodoc:
        super

        value = local_cache && local_cache.read(key)
        if value == NULL
          nil
        elsif value.nil?
          value = @data.get(key, raw?(options))
          local_cache.write(key, value || NULL) if local_cache
          value
        else
          # forcing the value to be immutable
          value.dup
        end
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        nil
      end

      # Writes a value to the cache.
      #
      # Possible options:
      # - +:unless_exist+ - set to true if you don't want to update the cache
      #   if the key is already set.
      # - +:expires_in+ - the number of seconds that this value may stay in
      #   the cache. See ActiveSupport::Cache::Store#write for an example.
      def write(key, value, options = nil)
        super
        method = options && options[:unless_exist] ? :add : :set
        # memcache-client will break the connection if you send it an integer
        # in raw mode, so we convert it to a string to be sure it continues working.
        value = value.to_s if raw?(options)
        local_cache.write(key, value || NULL) if local_cache
        response = @data.send(method, key, value, expires_in(options), raw?(options))
        response == Response::STORED
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        false
      end

      def delete(key, options = nil) # :nodoc:
        super
        local_cache.write(key, NULL) if local_cache
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
        value = local_cache.read(key) if local_cache
        if value == NULL
          false
        elsif value
          true
        else
          !read(key, options).nil?
        end
      end

      def increment(key, amount = 1) # :nodoc:
        log("incrementing", key, amount)

        response = @data.incr(key, amount)
        unless response == Response::NOT_FOUND
          local_cache.write(key, response.to_s) if local_cache
          response
        else
          nil
        end
      rescue MemCache::MemCacheError
        nil
      end

      def decrement(key, amount = 1) # :nodoc:
        log("decrement", key, amount)

        response = @data.decr(key, amount)
        unless response == Response::NOT_FOUND
          local_cache.write(key, response.to_s) if local_cache
          response
        else
          nil
        end
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
        local_cache.clear if local_cache
        @data.flush_all
      end

      def stats
        @data.stats
      end

      private
        def local_cache
          Thread.current[THREAD_LOCAL_KEY]
        end

        def expires_in(options)
          (options && options[:expires_in]) || 0
        end

        def raw?(options)
          options && options[:raw]
        end
    end
  end
end
