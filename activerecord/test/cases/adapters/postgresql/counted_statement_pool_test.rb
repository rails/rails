require 'cases/helper'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      class CountedStatementPoolTest < ActiveRecord::TestCase
        def test_store_and_fetch
          cache = CountedStatementPool.new 10
          10.times do |idx|
            assert_equal 0, cache["sql-#{idx}"], "default should be 0"
            cache["sql-#{idx}"] = idx
            assert_equal idx, cache["sql-#{idx}"]
          end
        end

        def test_error_on_too_big_counter
          cache = CountedStatementPool.new 10
          assert_raises(ArgumentError) do
            cache["sql"] = 10
          end
        end
      end
    end
  end
end
