# frozen_string_literal: true

require "cases/helper"
require "models/post"

class FieldOrderedValuesTest < ActiveRecord::TestCase
  fixtures :posts

  def test_in_order_of
    order = [3, 4, 1]
    posts = Post.in_order_of(:id, order).limit(3)

    assert_equal(order, posts.map(&:id))
  end

  def test_in_order_of_expression
    order = [3, 4, 1]
    posts = Post.in_order_of(Arel.sql("id * 2"), order.map { |id| id * 2 }).limit(3)

    assert_equal(order, posts.map(&:id))
  end

  def test_in_order_of_after_regular_order
    order = [3, 4, 1]
    posts = Post.where(type: "Post").order(:type).in_order_of(:id, order).limit(3)

    assert_equal(order, posts.map(&:id))
  end
end
