module ActiveSupport
  module Cache
    class MemoryStore < Store
      def initialize
        @data = {}
        @guard = Monitor.new
      end

      def fetch(key, options = {})
        @guard.synchronize do
          super
        end
      end

      def read(name, options = nil)
        @guard.synchronize do
          super
          @data[name]
        end
      end

      def write(name, value, options = nil)
        @guard.synchronize do
          super
          @data[name] = value.freeze
        end
      end

      def delete(name, options = nil)
        @guard.synchronize do
          @data.delete(name)
        end
      end

      def delete_matched(matcher, options = nil)
        @guard.synchronize do
          @data.delete_if { |k,v| k =~ matcher }
        end
      end

      def exist?(name,options = nil)
        @guard.synchronize do
          @data.has_key?(name)
        end
      end

      def increment(key, amount = 1)
        @guard.synchronize do
          super
        end
      end

      def decrement(key, amount = 1)
        @guard.synchronize do
          super
        end
      end

      def clear
        @guard.synchronize do
          @data.clear
        end
      end
    end
  end
end
