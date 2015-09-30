require 'cases/helper'

class MysqlStatementPoolTest < ActiveRecord::MysqlTestCase
  if Process.respond_to?(:fork)
    def test_cache_is_per_pid
      cache = ActiveRecord::ConnectionAdapters::MysqlAdapter::StatementPool.new(10)
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
