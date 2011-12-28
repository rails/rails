module ActiveRecord
  module ConnectionAdapters
    class StatementPool
      include Enumerable

      def initialize(connection, max = 1000)
        @connection = connection
        @max        = max
      end

      def each
        raise NotImplementedError
      end

      def key?(key)
        raise NotImplementedError
      end

      def [](key)
        raise NotImplementedError
      end

      def length
        raise NotImplementedError
      end

      def []=(sql, key)
        raise NotImplementedError
      end

      def clear
        raise NotImplementedError
      end

      def delete(key)
        raise NotImplementedError
      end
    end
  end
end
