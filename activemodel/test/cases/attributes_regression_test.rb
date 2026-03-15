# frozen_string_literal: true

require "cases/helper"

class AttributesRegressionTest < ActiveModel::TestCase
  class ModelWithoutSuper
    include ActiveModel::Model
    attribute :name, :string

    def initialize
      # super is not called
    end
  end

  test "handles missing @attributes when super is not called" do
    model = ModelWithoutSuper.new
    assert_nothing_raised do
      assert_equal ({}), model.attributes
      assert_equal [], model.attribute_names
      # Accessors
      assert_nil model.name
      model.name = "John"
      assert_nil model.name # write is a no-op if nil

      # Dup and Freeze
      model.dup
      model.freeze
    end
  end

  test "handles missing @attributes on allocated objects" do
    model = ModelWithoutSuper.allocate
    assert_nothing_raised do
      assert_equal ({}), model.attributes
      assert_equal [], model.attribute_names
      assert_nil model.name
      model.dup
      model.freeze
    end
  end
end
