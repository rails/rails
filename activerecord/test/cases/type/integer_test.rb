require "cases/helper"
require "models/company"

module ActiveRecord
  module Type
    class IntegerTest < ActiveRecord::TestCase
      test "simple values" do
        type = Type::Integer.new
        assert_equal 1, type.type_cast_from_user(1)
        assert_equal 1, type.type_cast_from_user('1')
        assert_equal 1, type.type_cast_from_user('1ignore')
        assert_equal 0, type.type_cast_from_user('bad1')
        assert_equal 0, type.type_cast_from_user('bad')
        assert_equal 1, type.type_cast_from_user(1.7)
        assert_equal 0, type.type_cast_from_user(false)
        assert_equal 1, type.type_cast_from_user(true)
        assert_nil type.type_cast_from_user(nil)
      end

      test "random objects cast to nil" do
        type = Type::Integer.new
        assert_nil type.type_cast_from_user([1,2])
        assert_nil type.type_cast_from_user({1 => 2})
        assert_nil type.type_cast_from_user((1..2))
      end

      test "casting ActiveRecord models" do
        type = Type::Integer.new
        firm = Firm.create(:name => 'Apple')
        assert_nil type.type_cast_from_user(firm)
      end

      test "casting objects without to_i" do
        type = Type::Integer.new
        assert_nil type.type_cast_from_user(::Object.new)
      end

      test "casting nan and infinity" do
        type = Type::Integer.new
        assert_nil type.type_cast_from_user(::Float::NAN)
        assert_nil type.type_cast_from_user(1.0/0.0)
      end

      test "changed?" do
        type = Type::Integer.new

        assert type.changed?(5, 5, '5wibble')
        assert_not type.changed?(5, 5, '5')
        assert_not type.changed?(5, 5, '5.0')
        assert_not type.changed?(-5, -5, '-5')
        assert_not type.changed?(-5, -5, '-5.0')
        assert_not type.changed?(nil, nil, nil)
      end

      test "values below int min value are out of range" do
        assert_raises(::RangeError) do
          Integer.new.type_cast_for_database(-2147483649)
        end
      end

      test "values above int max value are out of range" do
        assert_raises(::RangeError) do
          Integer.new.type_cast_for_database(2147483648)
        end
      end

      test "very small numbers are out of range" do
        assert_raises(::RangeError) do
          Integer.new.type_cast_for_database(-9999999999999999999999999999999)
        end
      end

      test "very large numbers are out of range" do
        assert_raises(::RangeError) do
          Integer.new.type_cast_for_database(9999999999999999999999999999999)
        end
      end

      test "normal numbers are in range" do
        type = Integer.new
        assert_equal(0, type.type_cast_for_database(0))
        assert_equal(-1, type.type_cast_for_database(-1))
        assert_equal(1, type.type_cast_for_database(1))
      end

      test "int max value is in range" do
        assert_equal(2147483647, Integer.new.type_cast_for_database(2147483647))
      end

      test "int min value is in range" do
        assert_equal(-2147483648, Integer.new.type_cast_for_database(-2147483648))
      end

      test "columns with a larger limit have larger ranges" do
        type = Integer.new(limit: 8)

        assert_equal(9223372036854775807, type.type_cast_for_database(9223372036854775807))
        assert_equal(-9223372036854775808, type.type_cast_for_database(-9223372036854775808))
        assert_raises(::RangeError) do
          type.type_cast_for_database(-9999999999999999999999999999999)
        end
        assert_raises(::RangeError) do
          type.type_cast_for_database(9999999999999999999999999999999)
        end
      end

      test "values which are out of range can be re-assigned" do
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = 'posts'
          attribute :foo, Type::Integer.new
        end
        model = klass.new

        model.foo = 2147483648
        model.foo = 1

        assert_equal 1, model.foo
      end
    end
  end
end
