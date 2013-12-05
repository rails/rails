require 'cases/helper'
require 'models/book'

class EnumTest < ActiveRecord::TestCase
  fixtures :books

  setup do
    @book = books(:awdr)
  end

  test "query state by predicate" do
    assert @book.proposed?
    assert_not @book.written?
    assert_not @book.published?

    assert @book.unread?
  end

  test "query state with symbol" do
    assert_equal "proposed", @book.status
    assert_equal "unread", @book.read_status
  end

  test "find via scope" do
    assert_equal @book, Book.proposed.first
    assert_equal @book, Book.unread.first
  end

  test "update by declaration" do
    @book.written!
    assert @book.written?
  end

  test "update by setter" do
    @book.update! status: :written
    assert @book.written?
  end

  test "enum methods are overwritable" do
    assert_equal "do publish work...", @book.published!
    assert @book.published?
  end

  test "direct assignment" do
    @book.status = :written
    assert @book.written?
  end

  test "assign string value" do
    @book.status = "written"
    assert @book.written?
  end

  test "assign non existing value raises an error" do
    e = assert_raises(ArgumentError) do
      @book.status = :unknown
    end
    assert_equal "'unknown' is not a valid status", e.message
  end

  test "constant to access the mapping" do
    assert_equal 0, Book::STATUS[:proposed]
    assert_equal 1, Book::STATUS["written"]
    assert_equal 2, Book::STATUS[:published]
  end

  test "implicit mapping with skipped values" do
    model = Class.new(ActiveRecord::Base) { enum category: [:a, nil, :c, :d, nil] }
    categories = model.const_get(:CATEGORY)
    assert_equal 3, categories.size
    assert_equal 0, categories[:a]
    assert_equal 2, categories[:c]
    assert_equal 3, categories[:d]
  end

  test "explict mapping with skipped values" do
    model = Class.new(ActiveRecord::Base) { enum category: { a: 0, b: nil, c: 2, d: 3, e: nil } }
    categories = model.const_get(:CATEGORY)
    assert_equal 3, categories.size
    assert_equal 0, categories[:a]
    assert_equal 2, categories[:c]
    assert_equal 3, categories[:d]
  end
end
