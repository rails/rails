# frozen_string_literal: true

require "cases/helper"

class SQLite3StatementPoolTest < ActiveRecord::SQLite3TestCase
  if Process.respond_to?(:fork)
    def test_cache_is_per_pid
      cache = ActiveRecord::ConnectionAdapters::SQLite3Adapter::StatementPool.new(10)
      cache["foo"] = "bar"
      assert_equal "bar", cache["foo"]

      pid = fork {
        lookup = cache["foo"]
        exit!(!lookup)
      }

      Process.waitpid pid
      assert_predicate $?, :success?, "process should exit successfully"
    end
  end
end
