# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  class AttributesTest < ActiveModel::TestCase
    class ModelForAttributesTest
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :integer_field, :integer
      attribute :string_field, :string
      attribute :decimal_field, :decimal
      attribute :string_with_default, :string, default: "default string"
      attribute :date_field, :date, default: -> { Date.new(2016, 1, 1) }
      attribute :boolean_field, :boolean
    end

    class ChildModelForAttributesTest < ModelForAttributesTest
    end

    class GrandchildModelForAttributesTest < ChildModelForAttributesTest
      attribute :integer_field, :string
    end

    test "properties assignment" do
      data = ModelForAttributesTest.new(
        integer_field: "2.3",
        string_field: "Rails FTW",
        decimal_field: "12.3",
        boolean_field: "0"
      )

      assert_equal 2, data.integer_field
      assert_equal "Rails FTW", data.string_field
      assert_equal BigDecimal("12.3"), data.decimal_field
      assert_equal "default string", data.string_with_default
      assert_equal Date.new(2016, 1, 1), data.date_field
      assert_equal false, data.boolean_field

      data.integer_field = 10
      data.string_with_default = nil
      data.boolean_field = "1"

      assert_equal 10, data.integer_field
      assert_nil data.string_with_default
      assert_equal true, data.boolean_field
    end

    test "nonexistent attribute" do
      assert_raise ActiveModel::UnknownAttributeError do
        ModelForAttributesTest.new(nonexistent: "nonexistent")
      end
    end

    test "children inherit attributes" do
      data = ChildModelForAttributesTest.new(integer_field: "4.4")

      assert_equal 4, data.integer_field
    end

    test "children can override parents" do
      data = GrandchildModelForAttributesTest.new(integer_field: "4.4")

      assert_equal "4.4", data.integer_field
    end

    test "attributes with proc defaults can be marshalled" do
      data = ModelForAttributesTest.new
      attributes = data.instance_variable_get(:@attributes)
      round_tripped = Marshal.load(Marshal.dump(data))
      new_attributes = round_tripped.instance_variable_get(:@attributes)

      assert_equal attributes, new_attributes
    end
  end
end
