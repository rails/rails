require 'cases/helper'
require 'models/book'

class StoreTest < ActiveRecord::TestCase
  fixtures :books

  setup do
    @book = books(:awdr)
  end

  test "query state by predicate" do
    assert @book.proposed?
    assert_not @book.written?
    assert_not @book.published?
  end

  test "query state with symbol" do
    assert_equal :proposed, @book.status
  end

  test "find via scope" do
    assert_equal @book, Book.proposed.first
  end

  test "update by declaration" do
    @book.written!
    assert @book.written?
  end

  test "update by setter" do
    @book.update! status: :written
    assert @book.written?
  end

  test "constant" do
    assert_equal 0, Book::STATUS[:proposed]
    assert_equal 1, Book::STATUS[:written]
    assert_equal 2, Book::STATUS[:published]
  end
end
