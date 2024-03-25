# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class ModelTest < ActiveModel::TestCase
      class Child
        include ActiveModel::API
        include ActiveModel::Attributes

        attribute :value, :integer
      end

      class Parent
        include ActiveModel::API
        include ActiveModel::Attributes

        attribute :child, :model, class: Child
        attribute :children, :model, class: Child, array: true

        attribute :child_string, :model, class_name: "ActiveModel::Type::ModelTest::Child"
        attribute :children_strings, :model, class_name: "ActiveModel::Type::ModelTest::Child", array: true
      end

      test "raises an ArgumentError when the class cannot be inferred" do
        assert_raises ArgumentError, match: "pass either a Class as the :class option or a String as the :class_name option" do
          Type::Model.new(class_name: :junk)
        end
      end

      test "#cast constantizes String" do
        type = Type::Model.new(class_name: "ActiveModel::Type::ModelTest::Parent")

        assert_kind_of Parent, type.cast({})
        assert_kind_of Child, type.cast(child_string: {}).child_string
        assert_kind_of Child, type.cast(children_strings: [{}]).children_strings.first
      end

      test "#cast simple values" do
        type = Type::Model.new(class: Parent)
        assert_nil type.cast(nil)
        assert_equal 1, type.cast(child: { value: "1" }).child.value
        assert_equal [1], type.cast(children: [{ value: "1" }]).children.map(&:value)
      end

      test "#cast passes instances by reference" do
        type = Type::Model.new(class: Parent)
        child = Child.new(value: 1)

        assert_same child, type.cast(child: child).child
        assert_same child, type.cast(children: [child]).children.first
      end

      test "#cast treats nil as nil" do
        type = Type::Model.new(class: Parent)

        assert_nil type.cast(nil)
        assert_nil type.cast(child: nil).child
        assert_equal [nil], type.cast(children: [nil]).children
      end

      test "#cast calls #attributes" do
        model = Class.new do
          def attributes = { value: 1 }

          def to_h = { value: 2 }
        end

        type = Type::Model.new(class: Parent)

        assert_equal 1, type.cast(child: model.new).child.value
        assert_equal [1], type.cast(children: [model.new]).children.map(&:value)
      end

      test "#cast falls back to #to_h when #attributes is not defined" do
        model = Class.new do
          def to_h = { value: 1 }
        end

        type = Type::Model.new(class: Parent)

        assert_equal 1, type.cast(child: model.new).child.value
        assert_equal [1], type.cast(children: [model.new]).children.map(&:value)
      end
    end
  end
end
