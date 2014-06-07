require 'cases/helper'

module ActiveRecord
  class AttributeDecoratorsTest < ActiveRecord::TestCase
    class Model < ActiveRecord::Base
      self.table_name = 'attribute_decorators_model'
    end

    class StringDecorator < SimpleDelegator
      def initialize(delegate, decoration = "decorated!")
        @decoration = decoration
        super(delegate)
      end

      def type_cast(value)
        "#{super} #{@decoration}"
      end
    end

    setup do
      @connection = ActiveRecord::Base.connection
      @connection.create_table :attribute_decorators_model, force: true do |t|
        t.string :a_string
      end
    end

    teardown do
      return unless @connection
      @connection.execute 'DROP TABLE IF EXISTS attribute_decorators_model'
      Model.attribute_type_decorations.clear
      Model.reset_column_information
    end

    test "attributes can be decorated" do
      model = Model.new(a_string: 'Hello')
      assert_equal 'Hello', model.a_string

      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }

      model = Model.new(a_string: 'Hello')
      assert_equal 'Hello decorated!', model.a_string
    end

    test "decoration does not eagerly load existing columns" do
      assert_no_queries do
        Model.reset_column_information
        Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      end
    end

    test "undecorated columns are not touched" do
      Model.attribute :another_string, Type::String.new, default: 'something or other'
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }

      assert_equal 'something or other', Model.new.another_string
    end

    test "decorators can be chained" do
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      Model.decorate_attribute_type(:a_string, :other) { |t| StringDecorator.new(t) }

      model = Model.new(a_string: 'Hello!')

      assert_equal 'Hello! decorated! decorated!', model.a_string
    end

    test "decoration of the same type multiple times is idempotent" do
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }

      model = Model.new(a_string: 'Hello')
      assert_equal 'Hello decorated!', model.a_string
    end

    test "decorations occur in order of declaration" do
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      Model.decorate_attribute_type(:a_string, :other) do |type|
        StringDecorator.new(type, 'decorated again!')
      end

      model = Model.new(a_string: 'Hello!')

      assert_equal 'Hello! decorated! decorated again!', model.a_string
    end

    test "decorating attributes does not modify parent classes" do
      Model.attribute :another_string, Type::String.new, default: 'whatever'
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }
      child_class = Class.new(Model)
      child_class.decorate_attribute_type(:another_string, :test) { |t| StringDecorator.new(t) }
      child_class.decorate_attribute_type(:a_string, :other) { |t| StringDecorator.new(t) }

      model = Model.new(a_string: 'Hello!')
      child = child_class.new(a_string: 'Hello!')

      assert_equal 'Hello! decorated!', model.a_string
      assert_equal 'whatever', model.another_string
      assert_equal 'Hello! decorated! decorated!', child.a_string
      # We are round tripping the default, and we don't undo our decoration
      assert_equal 'whatever decorated! decorated!', child.another_string
    end

    test "defaults are decorated on the column" do
      Model.attribute :a_string, Type::String.new, default: 'whatever'
      Model.decorate_attribute_type(:a_string, :test) { |t| StringDecorator.new(t) }

      column = Model.columns_hash['a_string']

      assert_equal 'whatever decorated!', column.default
    end
  end
end
