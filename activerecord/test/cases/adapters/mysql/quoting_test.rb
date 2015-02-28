require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      class QuotingTest < ActiveRecord::TestCase
        def setup
          @conn = ActiveRecord::Base.connection
        end

        def test_type_cast_true
          assert_equal 1, @conn.type_cast(true)
        end

        def test_type_cast_false
          assert_equal 0, @conn.type_cast(false)
        end
      end
    end
  end
end
