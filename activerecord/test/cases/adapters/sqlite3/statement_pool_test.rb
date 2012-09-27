require 'cases/helper'

module ActiveRecord::ConnectionAdapters
  class SQLite3Adapter
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
    end
  end
end

