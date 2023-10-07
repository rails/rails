# frozen_string_literal: true

require "cases/helper"

require "models/book"
require "models/author"

class ModelValidationTest < ActiveModel::TestCase
  def teardown
    Book.clear_validators!
    Author.clear_validators!
  end

  def test_validates_model_one
    Author.validates_presence_of(:name)
    Book.validates_model(:author)
    book = Book.new
    author = Author.new
    book.author = author

    assert_predicate book, :invalid?

    assert_equal ["is invalid"], book.errors[:author]
    assert_equal ["can't be blank"], author.errors[:name]

    author.name = "Matz"
    assert_predicate book, :valid?
  end

  def test_validates_model_many
    Book.validates_presence_of(:title)
    Author.validates_model(:books)
    valid_book = Book.new
    valid_book.title = "A valid Book"
    invalid_book = Book.new
    author = Author.new
    author.books = [invalid_book, valid_book]

    assert_predicate author, :invalid?

    assert_predicate author.errors[:books], :any?
    assert_predicate valid_book, :valid?
    assert_equal ["can't be blank"], invalid_book.errors[:title]

    invalid_book.title = "Another valid Book"
    assert_predicate invalid_book, :valid?
  end

  def test_validates_model_with_custom_message
    Author.validates_presence_of(:name)
    Book.validates_model(:author, message: "needs an author")
    book = Book.new
    author = Author.new
    book.author = author

    assert_predicate book, :invalid?

    assert_equal ["needs an author"], book.errors[:author]
    assert_equal ["can't be blank"], author.errors[:name]
  end

  def test_validates_model_missing
    Author.validates_presence_of(:name)
    Book.validates_model(:author, message: "needs an author")
    book = Book.new
    book.title = "A valid book"

    assert_predicate book, :valid?
  end

  def test_validates_model_with_custom_context
    Author.validates_presence_of :name, on: :custom
    Book.validates_model :author, on: :custom
    book = Book.new
    author = Author.new
    book.author = author

    assert_predicate book, :valid?

    assert_not book.valid?(:custom)
    assert_equal ["is invalid"], book.errors[:author]
    assert_equal ["can't be blank"], author.errors[:name]
  end
end
