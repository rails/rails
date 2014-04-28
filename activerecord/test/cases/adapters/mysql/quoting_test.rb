require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      class QuotingTest < ActiveRecord::TestCase
        def setup
          @conn = ActiveRecord::Base.connection
        end

        def test_type_cast_true
          assert_equal 1, @conn.type_cast(true, nil)
          assert_equal 1, @conn.type_cast(true, boolean_column)
          assert_equal '1', @conn.type_cast(true, string_column)
        end

        def test_type_cast_false
          assert_equal 0, @conn.type_cast(false, nil)
          assert_equal 0, @conn.type_cast(false, boolean_column)
          assert_equal '0', @conn.type_cast(false, string_column)
        end

        private

        def boolean_column
          c = Column.new(nil, 1, 'boolean')
        end

        def string_column
          c = Column.new(nil, nil, 'text')
        end
      end
    end
  end
end
