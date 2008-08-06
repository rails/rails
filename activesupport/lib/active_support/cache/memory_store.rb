module ActiveSupport
  module Cache
    class MemoryStore < Store
      def initialize
        @data = {}
        @mutex = Mutex.new
      end

      def fetch(key, options = {})
        @mutex.synchronize do
          super
        end
      end

      def read(name, options = nil)
        super
        @data[name]
      end

      def write(name, value, options = nil)
        super
        @data[name] = value
      end

      def delete(name, options = nil)
        @data.delete(name)
      end

      def delete_matched(matcher, options = nil)
        @data.delete_if { |k,v| k =~ matcher }
      end

      def exist?(name,options = nil)
        @data.has_key?(name)
      end

      def increment(key, amount = 1)
        @mutex.synchronize do
          super
        end
      end

      def decrement(key, amount = 1)
        @mutex.synchronize do
          super
        end
      end

      def clear
        @data.clear
      end
    end
  end
end
