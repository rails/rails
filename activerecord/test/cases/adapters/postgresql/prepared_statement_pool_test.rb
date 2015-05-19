require 'cases/helper'
require 'minitest/mock'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      class InactivePGconn
        def query(*args)
          raise PGError
        end

        def status
          PGconn::CONNECTION_BAD
        end

        def prepare(*args)
        end
      end

      class PreparedStatementPoolTest < ActiveRecord::TestCase
        def test_dealloc_does_not_raise_on_inactive_connection
          cache = PreparedStatementPool.new InactivePGconn.new, 10
          cache.add('foo', 'bar')
          assert_nothing_raised { cache.clear }
        end

        if Process.respond_to?(:fork)
          def test_cache_is_per_pid
            cache = PreparedStatementPool.new InactivePGconn.new, 10
            cache.add('foo', 'bar')
            assert_equal PreparedStatementPool::PoolEntry.new('a1'), cache['foo']

            pid = fork {
              lookup = cache['foo'];
              exit!(!lookup)
            }

            Process.waitpid pid
            assert $?.success?, 'process should exit successfully'
          end
        end

        def test_send_prepare_statements
          conn = Minitest::Mock.new
          cache = PreparedStatementPool.new conn, 10

          conn.expect :prepare, nil, ["a1", "SQL"]
          cache.add("stmt", "SQL")

          conn.verify
        end

        def with_filled_cache(conn, count)
          cache = PreparedStatementPool.new conn, 10

          count.times do |idx|
            conn.expect :prepare, nil, ["a#{idx+1}", "SQL #{idx}"]
            cache.add("stmt #{idx}", "SQL #{idx}")
          end

          yield cache
        end

        def test_deletes_least_recently_used
          conn = Minitest::Mock.new
          with_filled_cache(conn, 10) do |cache|
            cache['stmt 1']

            conn.expect :status, PGconn::CONNECTION_OK
            conn.expect :exec, nil, ['DEALLOCATE a1;DEALLOCATE a3;']
            cache.delete_oversized
          end
          conn.verify
        end

        def test_bundles_dealloc_statements_when_the_limit_is_reached
          conn = Minitest::Mock.new

          with_filled_cache(conn, 9) do |cache|
            cache.delete_oversized
            assert_equal 9, cache.length, "pool limit should not be reached"

            conn.expect :prepare, nil, ["a10", "SQL 10"]
            cache.add("stmt 10", "SQL 10")
            assert_equal 10, cache.length

            conn.expect :status, PGconn::CONNECTION_OK
            conn.expect :exec, nil, ['DEALLOCATE a1;DEALLOCATE a2;']
            cache.delete_oversized
            assert_operator 8, :<=, cache.length
          end

          conn.verify
        end
      end
    end
  end
end
