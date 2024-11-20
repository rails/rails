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
      attribute :string_field, default: "default string"
    end

    class ModelWithGeneratedAttributeMethods
      include ActiveModel::Attributes

      attribute :foo
    end

    class ModelWithProxiedAttributeMethods
      include ActiveModel::AttributeMethods

      attribute_method_suffix "="

      define_attribute_method(:foo)

      def attribute=(_, _)
      end
    end

    test "models that proxy attributes do not conflict with models with generated methods" do
      ModelWithGeneratedAttributeMethods.new

      model = ModelWithProxiedAttributeMethods.new

      assert_nothing_raised do
        model.foo = "foo"
      end
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

    test "reading attributes" do
      data = ModelForAttributesTest.new(
        integer_field: 1.1,
        string_field: 1.1,
        decimal_field: 1.1,
        boolean_field: 1.1
      )

      expected_attributes = {
        integer_field: 1,
        string_field: "1.1",
        decimal_field: BigDecimal("1.1"),
        string_with_default: "default string",
        date_field: Date.new(2016, 1, 1),
        boolean_field: true
      }.stringify_keys

      assert_equal expected_attributes, data.attributes
    end

    test "reading attribute names" do
      names = [
        "integer_field",
        "string_field",
        "decimal_field",
        "string_with_default",
        "date_field",
        "boolean_field"
      ]

      assert_equal names, ModelForAttributesTest.attribute_names
      assert_equal names, ModelForAttributesTest.new.attribute_names
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
      klass = GrandchildModelForAttributesTest

      assert_instance_of Type::String, klass.attribute_types["integer_field"]
      assert_instance_of Type::String, klass.attribute_types["string_field"]

      data = GrandchildModelForAttributesTest.new(integer_field: "4.4")

      assert_equal "4.4", data.integer_field
      assert_equal "default string", data.string_field
    end

    test "attributes with proc defaults can be marshalled" do
      data = ModelForAttributesTest.new
      attributes = data.instance_variable_get(:@attributes)
      round_tripped = Marshal.load(Marshal.dump(data))
      new_attributes = round_tripped.instance_variable_get(:@attributes)

      assert_equal attributes, new_attributes
    end

    test "attributes can be dup-ed" do
      data = ModelForAttributesTest.new
      data.integer_field = 1

      duped = data.dup

      assert_equal 1, data.integer_field
      assert_equal 1, duped.integer_field

      duped.integer_field = 2

      assert_equal 1, data.integer_field
      assert_equal 2, duped.integer_field
    end

    test "can't modify attributes if frozen" do
      data = ModelForAttributesTest.new
      data.freeze
      assert_predicate data, :frozen?
      assert_raise(FrozenError) { data.integer_field = 1 }
    end

    test "attributes can be frozen again" do
      data = ModelForAttributesTest.new
      data.freeze
      assert_nothing_raised { data.freeze }
    end

    test "unknown type error is raised" do
      assert_raise(ArgumentError) do
        ModelForAttributesTest.attribute :foo, :unknown
      end
    end

    test ".type_for_attribute supports attribute aliases" do
      with_alias = Class.new(ModelForAttributesTest) do
        alias_attribute :integer_field, :x
      end

      assert_equal with_alias.type_for_attribute(:integer_field), with_alias.type_for_attribute(:x)
    end
  end
end
