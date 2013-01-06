require "cases/helper"
require 'models/company'

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

      def test_type_cast_integer
        column = Column.new("field", nil, "integer")
        assert_equal 1, column.type_cast(1)
        assert_equal 1, column.type_cast('1')
        assert_equal 1, column.type_cast('1ignore')
        assert_equal 0, column.type_cast('bad1')
        assert_equal 0, column.type_cast('bad')
        assert_equal 1, column.type_cast(1.7)
        assert_equal 0, column.type_cast(false)
        assert_equal 1, column.type_cast(true)
        assert_nil column.type_cast(nil)
      end

      def test_type_cast_non_integer_to_integer
        column = Column.new("field", nil, "integer")
        assert_nil column.type_cast([1,2])
        assert_nil column.type_cast({1 => 2})
        assert_nil column.type_cast((1..2))
      end

      def test_type_cast_activerecord_to_integer
        column = Column.new("field", nil, "integer")
        firm = Firm.create(:name => 'Apple')
        assert_nil column.type_cast(firm)
      end

      def test_type_cast_object_without_to_i_to_integer
        column = Column.new("field", nil, "integer")
        assert_nil column.type_cast(Object.new)
      end

      if RUBY_VERSION > '1.9'
        def test_type_cast_nan_and_infinity_to_integer
          column = Column.new("field", nil, "integer")
          assert_nil column.type_cast(Float::NAN)
          assert_nil column.type_cast(1.0/0.0)
        end
      end
    end
  end
end
