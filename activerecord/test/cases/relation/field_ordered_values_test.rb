# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/book"

class FieldOrderedValuesTest < ActiveRecord::TestCase
  fixtures :posts

  def test_in_order_of
    order = [3, 4, 1]
    posts = Post.in_order_of(:id, order)

    assert_equal(order, posts.map(&:id))
  end

  def test_in_order_of_empty
    posts = Post.in_order_of(:id, [])

    assert_empty(posts)
  end

  def test_in_order_of_with_enums_values
    Book.destroy_all
    Book.create!(status: :proposed)
    Book.create!(status: :written)
    Book.create!(status: :published)

    order = %w[written published proposed]
    books = Book.in_order_of(:status, order)

    assert_equal(order, books.map(&:status))
  end

  def test_in_order_of_with_enums_keys
    Book.destroy_all
    Book.create!(status: :proposed)
    Book.create!(status: :written)
    Book.create!(status: :published)

    order = [Book.statuses[:written], Book.statuses[:published], Book.statuses[:proposed]]
    books = Book.in_order_of(:status, order)

    assert_equal(order, books.map { |book| Book.statuses[book.status] })
  end

  def test_in_order_of_expression
    order = [3, 4, 1]
    posts = Post.in_order_of(Arel.sql("id * 2"), order.map { |id| id * 2 })

    assert_equal(order, posts.map(&:id))
  end

  def test_in_order_of_after_regular_order
    order = [3, 4, 1]
    posts = Post.where(type: "Post").order(:type).in_order_of(:id, order)

    assert_equal(order, posts.map(&:id))
  end
end
