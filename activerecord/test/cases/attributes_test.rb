require "cases/helper"

class OverloadedType < ActiveRecord::Base
  attribute :overloaded_float, :integer
  attribute :overloaded_string_with_limit, :string, limit: 50
  attribute :non_existent_decimal, :decimal
  attribute :string_with_default, :string, default: "the overloaded default"
end

class ChildOfOverloadedType < OverloadedType
end

class GrandchildOfOverloadedType < ChildOfOverloadedType
  attribute :overloaded_float, :float
end

class UnoverloadedType < ActiveRecord::Base
  self.table_name = "overloaded_types"
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
      assert_kind_of Integer, OverloadedType.last.overloaded_float
      assert_equal 2.0, UnoverloadedType.last.overloaded_float
      assert_kind_of Float, UnoverloadedType.last.overloaded_float
    end

    test "properties assigned in constructor" do
      data = OverloadedType.new(overloaded_float: "3.3")

      assert_equal 3, data.overloaded_float
    end

    test "overloaded properties with limit" do
      assert_equal 50, OverloadedType.type_for_attribute("overloaded_string_with_limit").limit
      assert_equal 255, UnoverloadedType.type_for_attribute("overloaded_string_with_limit").limit
    end

    test "nonexistent attribute" do
      data = OverloadedType.new(non_existent_decimal: 1)

      assert_equal BigDecimal(1), data.non_existent_decimal
      assert_raise ActiveRecord::UnknownAttributeError do
        UnoverloadedType.new(non_existent_decimal: 1)
      end
    end

    test "model with nonexistent attribute with default value can be saved" do
      klass = Class.new(OverloadedType) do
        attribute :non_existent_string_with_default, :string, default: "nonexistent"
      end

      model = klass.new
      assert model.save
    end

    test "changing defaults" do
      data = OverloadedType.new
      unoverloaded_data = UnoverloadedType.new

      assert_equal "the overloaded default", data.string_with_default
      assert_equal "the original default", unoverloaded_data.string_with_default
    end

    test "defaults are not touched on the columns" do
      assert_equal "the original default", OverloadedType.columns_hash["string_with_default"].default
    end

    test "children inherit custom properties" do
      data = ChildOfOverloadedType.new(overloaded_float: "4.4")

      assert_equal 4, data.overloaded_float
    end

    test "children can override parents" do
      data = GrandchildOfOverloadedType.new(overloaded_float: "4.4")

      assert_equal 4.4, data.overloaded_float
    end

    test "overloading properties does not attribute method order" do
      attribute_names = OverloadedType.attribute_names
      assert_equal %w(id overloaded_float unoverloaded_float overloaded_string_with_limit string_with_default non_existent_decimal), attribute_names
    end

    test "caches are cleared" do
      klass = Class.new(OverloadedType)

      assert_equal 6, klass.attribute_types.length
      assert_equal 6, klass.column_defaults.length
      assert_not klass.attribute_types.include?("wibble")

      klass.attribute :wibble, Type::Value.new

      assert_equal 7, klass.attribute_types.length
      assert_equal 7, klass.column_defaults.length
      assert_includes klass.attribute_types, "wibble"
    end

    test "the given default value is cast from user" do
      custom_type = Class.new(Type::Value) do
        def cast(*)
          "from user"
        end

        def deserialize(*)
          "from database"
        end
      end

      klass = Class.new(OverloadedType) do
        attribute :wibble, custom_type.new, default: "default"
      end
      model = klass.new

      assert_equal "from user", model.wibble
    end

    test "procs for default values" do
      klass = Class.new(OverloadedType) do
        @@counter = 0
        attribute :counter, :integer, default: -> { @@counter += 1 }
      end

      assert_equal 1, klass.new.counter
      assert_equal 2, klass.new.counter
    end

    test "procs for default values are evaluated even after column_defaults is called" do
      klass = Class.new(OverloadedType) do
        @@counter = 0
        attribute :counter, :integer, default: -> { @@counter += 1 }
      end

      assert_equal 1, klass.new.counter

      # column_defaults will increment the counter since the proc is called
      klass.column_defaults

      assert_equal 3, klass.new.counter
    end

    test "procs are memoized before type casting" do
      klass = Class.new(OverloadedType) do
        @@counter = 0
        attribute :counter, :integer, default: -> { @@counter += 1 }
      end

      model = klass.new
      assert_equal 1, model.counter_before_type_cast
      assert_equal 1, model.counter_before_type_cast
    end

    test "user provided defaults are persisted even if unchanged" do
      model = OverloadedType.create!

      assert_equal "the overloaded default", model.reload.string_with_default
    end

    if current_adapter?(:PostgreSQLAdapter)
      test "array types can be specified" do
        klass = Class.new(OverloadedType) do
          attribute :my_array, :string, limit: 50, array: true
          attribute :my_int_array, :integer, array: true
        end

        string_array = ConnectionAdapters::PostgreSQL::OID::Array.new(
          Type::String.new(limit: 50))
        int_array = ConnectionAdapters::PostgreSQL::OID::Array.new(
          Type::Integer.new)
        assert_not_equal string_array, int_array
        assert_equal string_array, klass.type_for_attribute("my_array")
        assert_equal int_array, klass.type_for_attribute("my_int_array")
      end

      test "range types can be specified" do
        klass = Class.new(OverloadedType) do
          attribute :my_range, :string, limit: 50, range: true
          attribute :my_int_range, :integer, range: true
        end

        string_range = ConnectionAdapters::PostgreSQL::OID::Range.new(
          Type::String.new(limit: 50))
        int_range = ConnectionAdapters::PostgreSQL::OID::Range.new(
          Type::Integer.new)
        assert_not_equal string_range, int_range
        assert_equal string_range, klass.type_for_attribute("my_range")
        assert_equal int_range, klass.type_for_attribute("my_int_range")
      end
    end

    test "attributes added after subclasses load are inherited" do
      parent = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
      end

      child = Class.new(parent)
      child.new # => force a schema load

      parent.attribute(:foo, Type::Value.new)

      assert_equal(:bar, child.new(foo: :bar).foo)
    end

    test "attributes not backed by database columns are not dirty when unchanged" do
      refute OverloadedType.new.non_existent_decimal_changed?
    end

    test "attributes not backed by database columns are always initialized" do
      OverloadedType.create!
      model = OverloadedType.first

      assert_nil model.non_existent_decimal
      model.non_existent_decimal = "123"
      assert_equal 123, model.non_existent_decimal
    end

    test "attributes not backed by database columns return the default on models loaded from database" do
      child = Class.new(OverloadedType) do
        attribute :non_existent_decimal, :decimal, default: 123
      end
      child.create!
      model = child.first

      assert_equal 123, model.non_existent_decimal
    end

    test "attributes not backed by database columns properly interact with mutation and dirty" do
      child = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        attribute :foo, :string, default: "lol"
      end
      child.create!
      model = child.first

      assert_equal "lol", model.foo

      model.foo << "asdf"
      assert_equal "lolasdf", model.foo
      assert model.foo_changed?

      model.reload
      assert_equal "lol", model.foo

      model.foo = "lol"
      refute model.changed?
    end

    test "attributes not backed by database columns appear in inspect" do
      inspection = OverloadedType.new.inspect

      assert_includes inspection, "non_existent_decimal"
    end

    test "attributes do not require a type" do
      klass = Class.new(OverloadedType) do
        attribute :no_type
      end
      assert_equal 1, klass.new(no_type: 1).no_type
      assert_equal "foo", klass.new(no_type: "foo").no_type
    end
  end
end
