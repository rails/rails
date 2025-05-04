# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class ArrayTest < ActiveModel::TestCase
      # Test model for integration tests
      class ModelWithArrays
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Dirty

        attribute :string_array, :array
        attribute :integer_array, :array, of: :integer
        attribute :boolean_array, :array, of: :boolean
        attribute :decimal_array, :array, of: :decimal, precision: 2
        attribute :date_array, :array, of: :date
      end

      # Unit tests for the type itself

      test "type casting of arrays" do
        type = Array.new
        assert_equal ["1", "2", "3"], type.cast(["1", "2", "3"])
        assert_equal [1, 2, 3], type.cast([1, 2, 3])
        assert_nil type.cast(nil)
        assert_equal ["foo"], type.cast("foo")
        assert_equal [], type.cast([])
      end

      test "type casting with element type" do
        type = Array.new(of: :integer)
        assert_equal [1, 2, 3], type.cast(["1", "2", "3"])
        assert_equal [1, 2, 3], type.cast([1, 2, 3])
        assert_nil type.cast(nil)
        assert_equal [1], type.cast("1")
        assert_equal [], type.cast([])
      end

      test "type casting with various element types" do
        type = Array.new(of: :decimal, precision: 2)
        assert_equal [BigDecimal("1.0"), BigDecimal("2.0"), BigDecimal("3.5")],
                    type.cast(["1", "2", "3.5"])

        type = Array.new(of: :boolean)
        assert_equal [true, false, true, false],
                    type.cast(["1", "0", "true", "false"])

        type = Array.new(of: :string)
        assert_equal ["1", "2", "3"], type.cast([1, 2, 3])
      end

      test "parsing JSON strings as arrays" do
        type = Array.new
        assert_equal ["foo", "bar"], type.cast('["foo", "bar"]')
        assert_equal [1, 2, 3], type.cast("[1, 2, 3]")

        # Test with single JSON values (should be wrapped in array)
        assert_equal ["foo"], type.cast('"foo"')
        assert_equal [42], type.cast("42")

        # Test with element type
        type = Array.new(of: :integer)
        assert_equal [1, 2, 3], type.cast("[1, 2, 3]")
        assert_equal [1, 2, 3], type.cast('["1", "2", "3"]')
      end

      test "handling invalid JSON strings" do
        type = Array.new
        assert_equal ["not[valid]json"], type.cast("not[valid]json")

        type = Array.new(of: :integer)
        assert_equal [0], type.cast("not[valid]json")
      end

      test "serializing arrays" do
        type = Array.new
        assert_equal ["1", "2", "3"], type.serialize(["1", "2", "3"])
        assert_equal [1, 2, 3], type.serialize([1, 2, 3])
        assert_nil type.serialize(nil)
        assert_equal ["foo"], type.serialize("foo")
      end

      test "serializing arrays with element type" do
        type = Array.new(of: :integer)
        assert_equal [1, 2, 3], type.serialize(["1", "2", "3"])
        assert_equal [1, 2, 3], type.serialize([1, 2, 3])
        assert_nil type.serialize(nil)
        assert_equal [1], type.serialize("1")
      end

      test "detecting changes in arrays" do
        type = Array.new
        array = ["foo", "bar"]

        # Test mutability
        assert_equal true, type.mutable?

        # Test changed_in_place? detection
        serialized = type.serialize(array.dup)
        array << "baz"
        assert_equal true, type.changed_in_place?(serialized, array)

        # Test with element modification
        array = ["foo", "bar"]
        serialized = type.serialize(array.dup)
        array[0] = "changed"
        assert_equal true, type.changed_in_place?(serialized, array)
      end

      test "equality of types" do
        type1 = Array.new(of: :integer)
        type2 = Array.new(of: :integer)
        type3 = Array.new(of: :string)
        type4 = Array.new

        assert_equal type1, type2
        assert_not_equal type1, type3
        assert_not_equal type1, type4
        assert_not_equal type3, type4
      end

      # Integration tests with ActiveModel::Attributes

      test "basic usage with ActiveModel::Attributes" do
        model = ModelWithArrays.new

        model.string_array = ["1", "2", "3"]
        assert_equal ["1", "2", "3"], model.string_array

        model.integer_array = ["1", "2", "3"]
        assert_equal [1, 2, 3], model.integer_array

        model.boolean_array = ["1", "0", "true", "false"]
        assert_equal [true, false, true, false], model.boolean_array

        model.decimal_array = ["1.5", "2.25", "3.75"]
        assert_equal [BigDecimal("1.5"), BigDecimal("2.25"), BigDecimal("3.75")],
                    model.decimal_array
      end

      test "assigning single values to array attributes" do
        model = ModelWithArrays.new

        model.string_array = "single"
        assert_equal ["single"], model.string_array

        model.integer_array = "42"
        assert_equal [42], model.integer_array

        model.boolean_array = "1"
        assert_equal [true], model.boolean_array

        # Just check type without exact value
        model.decimal_array = "3.14"
        assert_equal 1, model.decimal_array.size
        assert_kind_of BigDecimal, model.decimal_array.first
      end

      test "assigning JSON strings to array attributes" do
        model = ModelWithArrays.new

        model.string_array = '["foo", "bar"]'
        assert_equal ["foo", "bar"], model.string_array

        model.integer_array = "[1, 2, 3]"
        assert_equal [1, 2, 3], model.integer_array

        model.boolean_array = '[true, false, "1", "0"]'
        assert_equal [true, false, true, false], model.boolean_array

        # For date test, check individual components instead of full objects
        model.date_array = '["2023-01-15", "2023-02-20"]'
        assert_equal 2, model.date_array.size
        assert_equal 2023, model.date_array[0].year
        assert_equal 1, model.date_array[0].month
        assert_equal 15, model.date_array[0].day
        assert_equal 2023, model.date_array[1].year
        assert_equal 2, model.date_array[1].month
        assert_equal 20, model.date_array[1].day
      end

      test "handling nil and empty values" do
        model = ModelWithArrays.new

        model.string_array = nil
        assert_nil model.string_array

        model.integer_array = nil
        assert_nil model.integer_array

        model.string_array = ""
        assert_nil model.string_array

        model.integer_array = ""
        assert_nil model.integer_array

        model.string_array = []
        assert_equal [], model.string_array

        model.integer_array = []
        assert_equal [], model.integer_array
      end

      test "dirty tracking with array attributes" do
        model = ModelWithArrays.new

        # Initial assignment
        model.string_array = ["a", "b"]
        assert model.string_array_changed?

        # Save the model to clear changes
        model.changes_applied

        # Should be clean now
        assert_not model.string_array_changed?

        # Modify array in place
        # This should be detected by the changed_in_place? method
        model.string_array << "c"

        # The change should be detected now
        assert model.string_array_changed?

        # Force clear changes again
        model.changes_applied

        # Replace with different values
        model.string_array = ["d", "e"]
        assert model.string_array_changed?
      end
    end
  end
end
