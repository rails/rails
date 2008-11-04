module ActiveSupport
  module Cache
    # A cache store implementation which stores everything into memory in the
    # same process. If you're running multiple Ruby on Rails server processes
    # (which is the case if you're using mongrel_cluster or Phusion Passenger),
    # then this means that your Rails server process instances won't be able
    # to share cache data with each other. If your application never performs
    # manual cache item expiry (e.g. when you're using generational cache keys),
    # then using MemoryStore is ok. Otherwise, consider carefully whether you
    # should be using this cache store.
    #
    # MemoryStore is not only able to store strings, but also arbitrary Ruby
    # objects.
    #
    # MemoryStore is not thread-safe. Use SynchronizedMemoryStore instead
    # if you need thread-safety.
    class MemoryStore < Store
      def initialize
        @data = {}
      end

      def read(name, options = nil)
        super
        @data[name]
      end

      def write(name, value, options = nil)
        super
        @data[name] = value.freeze
      end

      def delete(name, options = nil)
        super
        @data.delete(name)
      end

      def delete_matched(matcher, options = nil)
        super
        @data.delete_if { |k,v| k =~ matcher }
      end

      def exist?(name,options = nil)
        super
        @data.has_key?(name)
      end

      def clear
        @data.clear
      end
    end
  end
end
