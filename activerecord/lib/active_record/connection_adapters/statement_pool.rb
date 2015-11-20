module ActiveRecord
  module ConnectionAdapters
    class StatementPool
      include Enumerable

      def initialize(max = 1000)
        @cache = Hash.new { |h,pid| h[pid] = {} }
        @max = max
      end

      def each(&block)
        cache.each(&block)
      end

      def key?(key)
        cache.key?(key)
      end

      def [](key)
        cache[key]
      end

      def length
        cache.length
      end

      def []=(sql, stmt)
        while @max <= cache.size
          dealloc(cache.shift.last)
        end
        cache[sql] = stmt
      end

      def clear
        cache.each_value do |stmt|
          dealloc stmt
        end
        cache.clear
      end

      def delete(key)
        dealloc cache[key]
        cache.delete(key)
      end

      private

      def cache
        @cache[Process.pid]
      end

      def dealloc(stmt)
        raise NotImplementedError
      end
    end
  end
end
