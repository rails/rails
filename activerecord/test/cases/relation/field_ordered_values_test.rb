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

    books = Book.in_order_of("status", order)
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

  def test_in_order_of_with_string_column
    Book.destroy_all
    Book.create!(format: "paperback")
    Book.create!(format: "ebook")
    Book.create!(format: "hardcover")

    order = %w[hardcover paperback ebook]
    books = Book.in_order_of(:format, order)
    assert_equal(order, books.map(&:format))

    books = Book.in_order_of("format", order)
    assert_equal(order, books.map(&:format))
  end

  def test_in_order_of_after_regular_order
    order = [3, 4, 1]
    posts = Post.where(type: "Post").order(:type).in_order_of(:id, order)
    assert_equal(order, posts.map(&:id))

    posts = Post.where(type: "Post").order(:type).in_order_of("id", order)
    assert_equal(order, posts.map(&:id))
  end

  def test_in_order_of_with_nil
    Book.destroy_all
    Book.create!(format: "paperback")
    Book.create!(format: "ebook")
    Book.create!(format: nil)

    order = ["ebook", nil, "paperback"]
    books = Book.in_order_of(:format, order)
    assert_equal(order, books.map(&:format))

    books = Book.in_order_of("format", order)
    assert_equal(order, books.map(&:format))
  end

  def test_in_order_of_with_associations
    Author.destroy_all
    Book.destroy_all
    john = Author.create(name: "John")
    bob = Author.create(name: "Bob")
    anna = Author.create(name: "Anna")

    john.books.create
    bob.books.create
    anna.books.create

    order = ["Bob", "Anna", "John"]
    books = Book.joins(:author).in_order_of("authors.name", order)
    assert_equal(order, books.map { |book| book.author.name })

    books = Book.joins(:author).in_order_of(:"authors.name", order)
    assert_equal(order, books.map { |book| book.author.name })
  end
end
