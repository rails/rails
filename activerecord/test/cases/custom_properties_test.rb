require 'cases/helper'

class OverloadedType < ActiveRecord::Base
  property :overloaded_float, Type::Integer.new
  property :overloaded_string_with_limit, Type::String.new(limit: 50)
  property :non_existent_decimal, Type::Decimal.new
end

class ChildOfOverloadedType < OverloadedType
end

class GrandchildOfOverloadedType < ChildOfOverloadedType
  property :overloaded_float, Type::Float.new
end

class UnoverloadedType < ActiveRecord::Base
  self.table_name = 'overloaded_types'
end

module ActiveRecord
  class CustomPropertiesTest < ActiveRecord::TestCase
    def test_overloading_types
      data = OverloadedType.new

      data.overloaded_float = "1.1"
      data.unoverloaded_float = "1.1"

      assert_equal 1, data.overloaded_float
      assert_equal 1.1, data.unoverloaded_float
    end

    def test_overloaded_properties_save
      data = OverloadedType.new

      data.overloaded_float = "2.2"
      data.save!
      data.reload

      assert_equal 2, data.overloaded_float
      assert_equal 2.0, UnoverloadedType.last.overloaded_float
    end

    def test_properties_assigned_in_constructor
      data = OverloadedType.new(overloaded_float: '3.3')

      assert_equal 3, data.overloaded_float
    end

    def test_overloaded_properties_with_limit
      assert_equal 50, OverloadedType.columns_hash['overloaded_string_with_limit'].limit
      assert_equal 255, UnoverloadedType.columns_hash['overloaded_string_with_limit'].limit
    end

    def test_nonexistent_property
      data = OverloadedType.new(non_existent_decimal: 1)

      assert_equal BigDecimal.new(1), data.non_existent_decimal
      assert_raise ActiveRecord::UnknownAttributeError do
        UnoverloadedType.new(non_existent_decimal: 1)
      end
    end

    def test_overloaded_properties_have_no_default
      data = OverloadedType.new
      unoverloaded_data = UnoverloadedType.new

      assert_nil data.overloaded_float
      assert unoverloaded_data.overloaded_float
    end

    def test_children_inherit_custom_properties
      data = ChildOfOverloadedType.new(overloaded_float: '4.4')

      assert_equal 4, data.overloaded_float
    end

    def test_children_can_override_parents
      data = GrandchildOfOverloadedType.new(overloaded_float: '4.4')

      assert_equal 4.4, data.overloaded_float
    end

    def test_overloading_properties_does_not_change_column_order
      column_names = OverloadedType.column_names
      assert_equal %w(id overloaded_float unoverloaded_float overloaded_string_with_limit non_existent_decimal), column_names
    end
  end
end
