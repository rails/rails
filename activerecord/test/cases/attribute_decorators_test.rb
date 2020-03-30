# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class AttributeDecoratorsTest < ActiveRecord::TestCase
    class Model < ActiveRecord::Base
      self.table_name = "attribute_decorators_model"
    end

    class StringDecorator < SimpleDelegator
      def initialize(delegate, decoration = "decorated!")
        @decoration = decoration
        super(delegate)
      end

      def cast(value)
        "#{super} #{@decoration}"
      end

      alias deserialize cast
    end

    setup do
      @connection = ActiveRecord::Base.connection
      @connection.create_table :attribute_decorators_model, force: true do |t|
        t.string :a_string
      end
    end

    teardown do
      return unless @connection
      @connection.drop_table "attribute_decorators_model", if_exists: true
      Model.deferred_attribute_type_decorations.clear
      Model.reset_column_information
    end

    test "attributes can be decorated" do
      model = Model.new(a_string: "Hello")
      assert_equal "Hello", model.a_string

      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }

      model = Model.new(a_string: "Hello")
      assert_equal "Hello decorated!", model.a_string
    end

    test "decoration does not eagerly load existing columns" do
      Model.reset_column_information
      assert_no_queries do
        Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      end
    end

    test "undecorated columns are not touched" do
      Model.attribute :another_string, :string, default: "something or other"
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }

      assert_equal "something or other", Model.new.another_string
    end

    test "decorators can be chained" do
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      Model.decorate_attribute_type(:a_string, :other) { |t| StringDecorator.new(t) }

      model = Model.new(a_string: "Hello!")

      assert_equal "Hello! decorated! decorated!", model.a_string
    end

    test "decoration of the same type multiple times is idempotent" do
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }

      model = Model.new(a_string: "Hello")
      assert_equal "Hello decorated!", model.a_string
    end

    test "decorations occur in order of declaration" do
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      Model.decorate_attribute_type(:a_string, :other) do |type|
        StringDecorator.new(type, "decorated again!")
      end

      model = Model.new(a_string: "Hello!")

      assert_equal "Hello! decorated! decorated again!", model.a_string
    end

    test "decorating attributes does not modify parent classes" do
      Model.attribute :another_string, :string, default: "whatever"
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      child_class = Class.new(Model)
      child_class.decorate_attribute_type(:another_string, :test) { |t| StringDecorator.new(t) }
      child_class.decorate_attribute_type(:a_string, :other) { |t| StringDecorator.new(t) }

      model = Model.new(a_string: "Hello!")
      child = child_class.new(a_string: "Hello!")

      assert_equal "Hello! decorated!", model.a_string
      assert_equal "whatever", model.another_string
      assert_equal "Hello! decorated! decorated!", child.a_string
      assert_equal "whatever decorated!", child.another_string
    end

    test "decorations added after subclass decorations added are inherited" do
      Model.attribute :another_string, :string
      child_class = Class.new(Model)
      child_class.decorate_attribute_type(:another_string, :test) { |t| StringDecorator.new(t) }
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }

      child = child_class.new(a_string: "Hello!")

      assert_equal "Hello! decorated!", child.a_string
    end

    class Multiplier < SimpleDelegator
      def cast(value)
        return if value.nil?
        value * 2
      end
      alias deserialize cast
    end

    test "decorating with a proc" do
      Model.attribute :an_int, :integer
      type_is_integer = proc { |_, type| type.type == :integer }
      Model.decorate_matching_attribute_types type_is_integer, :multiplier do |type|
        Multiplier.new(type)
      end

      model = Model.new(a_string: "whatever", an_int: 1)

      assert_equal "whatever", model.a_string
      assert_equal 2, model.an_int
    end
  end
end
