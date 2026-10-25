# :markup: markdown
# frozen_string_literal: true

module ActiveSupport
  # On MRI, individual WeakKeyMap operations run under the GVL, so only
  # other runtimes need a mutex around them.
  if RUBY_ENGINE == "ruby"
    class WeakKeyMap < ObjectSpace::WeakKeyMap # :nodoc:
    end
  else
    class WeakKeyMap # :nodoc:
      def initialize
        @map = ObjectSpace::WeakKeyMap.new
        @mutex = Mutex.new
      end

      def [](key)
        @mutex.synchronize { @map[key] }
      end

      def []=(key, value)
        @mutex.synchronize { @map[key] = value }
      end

      def delete(key)
        @mutex.synchronize { @map.delete(key) }
      end

      def clear
        @mutex.synchronize { @map.clear }
        self
      end
    end
  end

  class WeakKeyMap # :nodoc:
    # Returns the cached value, computing and storing it when nil. This is not
    # atomic: concurrent misses may double-compute and then return different values.
    def fetch_or_store(key)
      value = self[key]
      return value unless value.nil?
      value = yield
      self[key] ||= value
    end
  end
end
