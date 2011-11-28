require 'cases/helper'

module ActiveRecord::ConnectionAdapters
  class PostgreSQLAdapter < AbstractAdapter
    class InactivePGconn
      def query(*args)
        raise PGError
      end

      def status
        PGconn::CONNECTION_BAD
      end
    end

    class StatementPoolTest < ActiveRecord::TestCase
      def test_cache_is_per_pid
        return skip('must support fork') unless Process.respond_to?(:fork)

        cache = StatementPool.new nil, 10
        cache['foo'] = 'bar'
        assert_equal 'bar', cache['foo']

        pid = fork {
          lookup = cache['foo'];
          exit!(!lookup)
        }

        Process.waitpid pid
        assert $?.success?, 'process should exit successfully'
      end

      def test_dealloc_does_not_raise_on_inactive_connection
        cache = StatementPool.new InactivePGconn.new, 10
        cache['foo'] = 'bar'
        assert_nothing_raised { cache.clear }
      end
    end
  end
end
