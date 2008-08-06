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
        @mutex.synchronize do
          super
          @data[name]
        end
      end

      def write(name, value, options = nil)
        @mutex.synchronize do
          super
          @data[name] = value
        end
      end

      def delete(name, options = nil)
        @mutex.synchronize do
          super
          @data.delete(name)
        end
      end

      def delete_matched(matcher, options = nil)
        @mutex.synchronize do
          super
          @data.delete_if { |k,v| k =~ matcher }
        end
      end

      def exist?(name,options = nil)
        @mutex.synchronize do
          super
          @data.has_key?(name)
        end
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
        @mutex.synchronize do
          @data.clear
        end
      end
    end
  end
end
