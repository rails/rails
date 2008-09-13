module ActiveSupport
  module Cache
    class SynchronizedMemoryStore < MemoryStore
      def initialize
        super
        @guard = Monitor.new
      end

      def fetch(key, options = {})
        @guard.synchronize { super }
      end

      def read(name, options = nil)
        @guard.synchronize { super }
      end

      def write(name, value, options = nil)
        @guard.synchronize { super }
      end

      def delete(name, options = nil)
        @guard.synchronize { super }
      end

      def delete_matched(matcher, options = nil)
        @guard.synchronize { super }
      end

      def exist?(name,options = nil)
        @guard.synchronize { super }
      end

      def increment(key, amount = 1)
        @guard.synchronize { super }
      end

      def decrement(key, amount = 1)
        @guard.synchronize { super }
      end

      def clear
        @guard.synchronize { super }
      end
    end
  end
end
