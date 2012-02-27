require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ColumnTest < ActiveRecord::TestCase
      def test_type_cast_boolean
        column = Column.new("field", nil, "boolean")
        assert column.type_cast(true)
        assert column.type_cast(1)
        assert column.type_cast('1')
        assert column.type_cast('t')
        assert column.type_cast('T')
        assert column.type_cast('true')
        assert column.type_cast('TRUE')
        assert column.type_cast('on')
        assert column.type_cast('ON')
        assert !column.type_cast(false)
        assert !column.type_cast(0)
        assert !column.type_cast('0')
        assert !column.type_cast('f')
        assert !column.type_cast('F')
        assert !column.type_cast('false')
        assert !column.type_cast('FALSE')
        assert !column.type_cast('off')
        assert !column.type_cast('OFF')
      end
    end
  end
end
