require 'cases/helper'

module ActiveRecord::ConnectionAdapters
  class MysqlAdapter
    class StatementPoolTest < ActiveRecord::TestCase
      if Process.respond_to?(:fork)
        def test_cache_is_per_pid
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
end
