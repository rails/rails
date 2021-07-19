# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  class StructuralCompatibilityTest < ActiveRecord::TestCase
    fixtures :posts

    def test_compatible_values
      left = Post.where(id: 1)
      right = Post.where(id: 2)

      assert left.structurally_compatible?(right)
    end

    def test_incompatible_single_value_relations
      left = Post.distinct.where("id = 1")
      right = Post.where(id: [2, 3])

      assert_not left.structurally_compatible?(right)
    end

    def test_incompatible_multi_value_relations
      left = Post.order("body asc").where("id = 1")
      right = Post.order("id desc").where(id: [2, 3])

      assert_not left.structurally_compatible?(right)
    end

    def test_incompatible_unscope
      left = Post.order("body asc").where("id = 1").unscope(:order)
      right = Post.order("body asc").where("id = 2")

      assert_not left.structurally_compatible?(right)
    end
  end
end
