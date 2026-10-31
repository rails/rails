# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class StatementPool # :nodoc:
      include Enumerable

      DEFAULT_STATEMENT_LIMIT = 1000

      def initialize(statement_limit = nil)
        @cache = Hash.new { |h, pid| h[pid] = {} }
        @statement_limit = statement_limit || DEFAULT_STATEMENT_LIMIT
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
        while @statement_limit <= cache.size
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

      # Clear the pool without deallocating; this is only safe when we
      # know the server has independently deallocated all statements
      # (e.g. due to a reconnect, or a DISCARD ALL)
      def reset
        cache.clear
      end

      def delete(key)
        if stmt = cache.delete(key)
          dealloc(stmt)
        end
        stmt
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
