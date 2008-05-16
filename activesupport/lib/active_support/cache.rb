require 'benchmark'

module ActiveSupport
  module Cache
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
      when key.respond_to?(:to_param)
        key.to_param
      end

      expanded_cache_key
    end


    class Store
      cattr_accessor :logger

      def initialize
      end

      def threadsafe!
        @mutex = Mutex.new
        self.class.send :include, ThreadSafety
        self
      end

      # Pass <tt>:force => true</tt> to force a cache miss.
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

          log("write (will save #{'%.5f' % seconds})", key, nil)

          value
        end
      end

      def read(key, options = nil)
        log("read", key, options)
      end

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
          logger.debug("Cache #{operation}: #{key}#{options ? " (#{options.inspect})" : ""}") if logger && !@logger_off
        end
    end


    module ThreadSafety #:nodoc:
      def read(key, options = nil) #:nodoc:
        @mutex.synchronize { super }
      end

      def write(key, value, options = nil) #:nodoc:
        @mutex.synchronize { super }
      end

      def delete(key, options = nil) #:nodoc:
        @mutex.synchronize { super }
      end

      def delete_matched(matcher, options = nil) #:nodoc:
        @mutex.synchronize { super }
      end
    end
  end
end

require 'active_support/cache/file_store'
require 'active_support/cache/memory_store'
require 'active_support/cache/drb_store'
require 'active_support/cache/mem_cache_store'
require 'active_support/cache/compressed_mem_cache_store'
