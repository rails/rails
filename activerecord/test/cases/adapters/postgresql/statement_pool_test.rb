# frozen_string_literal: true

require "cases/helper"
require "models/computer"
require "models/developer"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      class InactivePgConnection
        def query(*args)
          raise PG::Error
        end

        def status
          PG::CONNECTION_BAD
        end
      end

      class StatementPoolTest < ActiveRecord::PostgreSQLTestCase
        fixtures :developers

        if Process.respond_to?(:fork)
          def test_cache_is_per_pid
            cache = StatementPool.new nil, 10
            cache["foo"] = "bar"
            assert_equal "bar", cache["foo"]

            pid = fork {
              lookup = cache["foo"]
              exit!(!lookup)
            }

            Process.waitpid pid
            assert $?.success?, "process should exit successfully"
          end
        end

        def test_dealloc_does_not_raise_on_inactive_connection
          cache = StatementPool.new InactivePgConnection.new, 10
          cache["foo"] = "bar"
          assert_nothing_raised { cache.clear }
        end

        def test_prepared_statements_do_not_get_stuck_on_query_interruption
          pg_connection = ActiveRecord::Base.connection.instance_variable_get(:@connection)
          pg_connection.stub(:get_last_result, -> { raise "random error" }) do
            assert_raises(RuntimeError) do
              Developer.where(name: "David").last
            end

            # without fix, this raises PG::DuplicatePstatement: ERROR:  prepared statement "a3" already exists
            assert_raises(RuntimeError) do
              Developer.where(name: "David").last
            end
          end
        end
      end
    end
  end
end
