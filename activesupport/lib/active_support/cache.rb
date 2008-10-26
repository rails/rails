require 'benchmark'

module ActiveSupport
  # See ActiveSupport::Cache::Store for documentation.
  module Cache
    # Creates a new CacheStore object according to the given options.
    #
    # If no arguments are passed to this method, then a new
    # ActiveSupport::Cache::MemoryStore object will be returned.
    #
    # If you pass a Symbol as the first argument, then a corresponding cache
    # store class under the ActiveSupport::Cache namespace will be created.
    # For example:
    #
    #   ActiveSupport::Cache.lookup_store(:memory_store)
    #   # => returns a new ActiveSupport::Cache::MemoryStore object
    #   
    #   ActiveSupport::Cache.lookup_store(:drb_store)
    #   # => returns a new ActiveSupport::Cache::DRbStore object
    #
    # Any additional arguments will be passed to the corresponding cache store
    # class's constructor:
    #
    #   ActiveSupport::Cache.lookup_store(:file_store, "/tmp/cache")
    #   # => same as: ActiveSupport::Cache::FileStore.new("/tmp/cache")
    #
    # If the first argument is not a Symbol, then it will simply be returned:
    #
    #   ActiveSupport::Cache.lookup_store(MyOwnCacheStore.new)
    #   # => returns MyOwnCacheStore.new
    def self.lookup_store(*store_option)
      store, *parameters = *([ store_option ].flatten)

      case store
      when Symbol
        store_class_name = (store == :drb_store ? "DRbStore" : store.to_s.camelize)
        store_class = ActiveSupport::Cache.const_get(store_class_name)
        store_class.new(*parameters)
      when nil
        ActiveSupport::Cache::MemoryStore.new
      else
        store
      end
    end

    def self.expand_cache_key(key, namespace = nil)
      expanded_cache_key = namespace ? "#{namespace}/" : ""

      if ENV["RAILS_CACHE_ID"] || ENV["RAILS_APP_VERSION"]
        expanded_cache_key << "#{ENV["RAILS_CACHE_ID"] || ENV["RAILS_APP_VERSION"]}/"
      end

      expanded_cache_key << case
        when key.respond_to?(:cache_key)
          key.cache_key
        when key.is_a?(Array)
          key.collect { |element| expand_cache_key(element) }.to_param
        when key
          key.to_param
        end.to_s

      expanded_cache_key
    end

    # An abstract cache store class. There are multiple cache store
    # implementations, each having its own additional features. See the classes
    # under the ActiveSupport::Cache module, e.g.
    # ActiveSupport::Cache::MemCacheStore. MemCacheStore is currently the most
    # popular cache store for large production websites.
    #
    # ActiveSupport::Cache::Store is meant for caching strings. Some cache
    # store implementations, like MemoryStore, are able to cache arbitrary
    # Ruby objects, but don't count on every cache store to be able to do that.
    #
    #   cache = ActiveSupport::Cache::MemoryStore.new
    #   
    #   cache.read("city")   # => nil
    #   cache.write("city", "Duckburgh")
    #   cache.read("city")   # => "Duckburgh"
    class Store
      cattr_accessor :logger

      def silence!
        @silence = true
        self
      end

      # Fetches data from the cache, using the given key. If there is data in
      # the cache with the given key, then that data is returned.
      #
      # If there is no such data in the cache (a cache miss occurred), then
      # then nil will be returned. However, if a block has been passed, then
      # that block will be run in the event of a cache miss. The return value
      # of the block will be written to the cache under the given cache key,
      # and that return value will be returned.
      #
      #   cache.write("today", "Monday")
      #   cache.fetch("today")  # => "Monday"
      #   
      #   cache.fetch("city")   # => nil
      #   cache.fetch("city") do
      #     "Duckburgh"
      #   end
      #   cache.fetch("city")   # => "Duckburgh"
      #
      # You may also specify additional options via the +options+ argument.
      # Setting <tt>:force => true</tt> will force a cache miss:
      #
      #   cache.write("today", "Monday")
      #   cache.fetch("today", :force => true)  # => nil
      #
      # Other options will be handled by the specific cache store implementation.
      # Internally, #fetch calls #read, and calls #write on a cache miss.
      # +options+ will be passed to the #read and #write calls.
      #
      # For example, MemCacheStore's #write method supports the +:expires_in+
      # option, which tells the memcached server to automatically expire the
      # cache item after a certain period. We can use this option with #fetch
      # too:
      #
      #   cache = ActiveSupport::Cache::MemCacheStore.new
      #   cache.fetch("foo", :force => true, :expires_in => 5.seconds) do
      #     "bar"
      #   end
      #   cache.fetch("foo")  # => "bar"
      #   sleep(6)
      #   cache.fetch("foo")  # => nil
      def fetch(key, options = {})
        @logger_off = true
        if !options[:force] && value = read(key, options)
          @logger_off = false
          log("hit", key, options)
          value
        elsif block_given?
          @logger_off = false
          log("miss", key, options)

          value = nil
          seconds = Benchmark.realtime { value = yield }

          @logger_off = true
          write(key, value, options)
          @logger_off = false

          log("write (will save #{'%.2f' % (seconds * 1000)}ms)", key, nil)

          value
        end
      end

      # Fetches data from the cache, using the given key. If there is data in
      # the cache with the given key, then that data is returned. Otherwise,
      # nil is returned.
      #
      # You may also specify additional options via the +options+ argument.
      # The specific cache store implementation will decide what to do with
      # +options+.
      def read(key, options = nil)
        log("read", key, options)
      end

      # Writes the given value to the cache, with the given key.
      #
      # You may also specify additional options via the +options+ argument.
      # The specific cache store implementation will decide what to do with
      # +options+.
      # 
      # For example, MemCacheStore supports the +:expires_in+ option, which
      # tells the memcached server to automatically expire the cache item after
      # a certain period:
      #
      #   cache = ActiveSupport::Cache::MemCacheStore.new
      #   cache.write("foo", "bar", :expires_in => 5.seconds)
      #   cache.read("foo")  # => "bar"
      #   sleep(6)
      #   cache.read("foo")  # => nil
      def write(key, value, options = nil)
        log("write", key, options)
      end

      def delete(key, options = nil)
        log("delete", key, options)
      end

      def delete_matched(matcher, options = nil)
        log("delete matched", matcher.inspect, options)
      end

      def exist?(key, options = nil)
        log("exist?", key, options)
      end

      def increment(key, amount = 1)
        log("incrementing", key, amount)
        if num = read(key)
          write(key, num + amount)
        else
          nil
        end
      end

      def decrement(key, amount = 1)
        log("decrementing", key, amount)
        if num = read(key)
          write(key, num - amount)
        else
          nil
        end
      end

      private
        def log(operation, key, options)
          logger.debug("Cache #{operation}: #{key}#{options ? " (#{options.inspect})" : ""}") if logger && !@silence && !@logger_off
        end
    end
  end
end

require 'active_support/cache/file_store'
require 'active_support/cache/memory_store'
require 'active_support/cache/drb_store'
require 'active_support/cache/mem_cache_store'
require 'active_support/cache/compressed_mem_cache_store'
