require 'cases/helper'

class OverloadedType < ActiveRecord::Base
  attribute :overloaded_float, Type::Integer.new
  attribute :overloaded_string_with_limit, Type::String.new(limit: 50)
  attribute :non_existent_decimal, Type::Decimal.new
  attribute :string_with_default, Type::String.new, default: 'the overloaded default'
end

class ChildOfOverloadedType < OverloadedType
end

class GrandchildOfOverloadedType < ChildOfOverloadedType
  attribute :overloaded_float, Type::Float.new
end

class UnoverloadedType < ActiveRecord::Base
  self.table_name = 'overloaded_types'
end

module ActiveRecord
  class CustomPropertiesTest < ActiveRecord::TestCase
    test "overloading types" do
      data = OverloadedType.new

      data.overloaded_float = "1.1"
      data.unoverloaded_float = "1.1"

      assert_equal 1, data.overloaded_float
      assert_equal 1.1, data.unoverloaded_float
    end

    test "overloaded properties save" do
      data = OverloadedType.new

      data.overloaded_float = "2.2"
      data.save!
      data.reload

      assert_equal 2, data.overloaded_float
      assert_kind_of Fixnum, OverloadedType.last.overloaded_float
      assert_equal 2.0, UnoverloadedType.last.overloaded_float
      assert_kind_of Float, UnoverloadedType.last.overloaded_float
    end

    test "properties assigned in constructor" do
      data = OverloadedType.new(overloaded_float: '3.3')

      assert_equal 3, data.overloaded_float
    end

    test "overloaded properties with limit" do
      assert_equal 50, OverloadedType.columns_hash['overloaded_string_with_limit'].limit
      assert_equal 255, UnoverloadedType.columns_hash['overloaded_string_with_limit'].limit
    end

    test "nonexistent attribute" do
      data = OverloadedType.new(non_existent_decimal: 1)

      assert_equal BigDecimal.new(1), data.non_existent_decimal
      assert_raise ActiveRecord::UnknownAttributeError do
        UnoverloadedType.new(non_existent_decimal: 1)
      end
    end

    test "changing defaults" do
      data = OverloadedType.new
      unoverloaded_data = UnoverloadedType.new

      assert_equal 'the overloaded default', data.string_with_default
      assert_equal 'the original default', unoverloaded_data.string_with_default
    end

    test "defaults are not touched on the columns" do
      assert_equal 'the original default', OverloadedType.columns_hash['string_with_default'].default
    end

    test "children inherit custom properties" do
      data = ChildOfOverloadedType.new(overloaded_float: '4.4')

      assert_equal 4, data.overloaded_float
    end

    test "children can override parents" do
      data = GrandchildOfOverloadedType.new(overloaded_float: '4.4')

      assert_equal 4.4, data.overloaded_float
    end

    test "overloading properties does not change column order" do
      column_names = OverloadedType.column_names
      assert_equal %w(id overloaded_float unoverloaded_float overloaded_string_with_limit string_with_default non_existent_decimal), column_names
    end

    test "caches are cleared" do
      klass = Class.new(OverloadedType)

      assert_equal 6, klass.columns.length
      assert_not klass.columns_hash.key?('wibble')
      assert_equal 6, klass.column_types.length
      assert_equal 6, klass.column_defaults.length
      assert_not klass.column_names.include?('wibble')
      assert_equal 5, klass.content_columns.length

      klass.attribute :wibble, Type::Value.new

      assert_equal 7, klass.columns.length
      assert klass.columns_hash.key?('wibble')
      assert_equal 7, klass.column_types.length
      assert_equal 7, klass.column_defaults.length
      assert klass.column_names.include?('wibble')
      assert_equal 6, klass.content_columns.length
    end

    test "non string/integers use custom types for queries" do
      klass = Class.new(OverloadedType)
      type = Type::Value.new
      def type.cast_value(value)
        !!value
      end

      def type.type_cast_for_database(value)
        if value
          "Y"
        else
          "N"
        end
      end

      klass.attribute(:string_with_default, type, default: false)
      klass.create!(string_with_default: true)

      assert_equal 1, klass.where(string_with_default: true).count
    end
  end
end
