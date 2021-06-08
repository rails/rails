# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  class TypeTest < ActiveModel::TestCase
    setup do
      @old_registry = ActiveModel::Type.registry
      ActiveModel::Type.registry = @old_registry.dup
    end

    teardown do
      ActiveModel::Type.registry = @old_registry
    end

    test "registering a new type" do
      type = Struct.new(:args)
      ActiveModel::Type.register(:foo, type)

      assert_equal type.new(:arg), ActiveModel::Type.lookup(:foo, :arg)
      assert_equal type.new({}), ActiveModel::Type.lookup(:foo, {})
    end
  end
end
