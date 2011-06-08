require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      class QuotingTest < ActiveRecord::TestCase
        def setup
          @conn = ActiveRecord::Base.connection
        end

        def test_type_cast_true
          c = Column.new(nil, 1, 'boolean')
          assert_equal 1, @conn.type_cast(true, nil)
          assert_equal 1, @conn.type_cast(true, c)
        end

        def test_type_cast_false
          c = Column.new(nil, 1, 'boolean')
          assert_equal 0, @conn.type_cast(false, nil)
          assert_equal 0, @conn.type_cast(false, c)
        end
      end
    end
  end
end
