# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/book"

class OrderTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses

  def setup
    Book.delete_all
  end

  def test_order_asc
    z = Book.create!(name: "Zulu", author: authors(:david))
    y = Book.create!(name: "Yankee", author: authors(:mary))
    x = Book.create!(name: "X-Ray", author: authors(:david))

    alphabetical = [x, y, z]

    assert_equal(alphabetical, Book.order(name: :asc))
    assert_equal(alphabetical, Book.order(name: :ASC))
    assert_equal(alphabetical, Book.order(name: "asc"))
    assert_equal(alphabetical, Book.order(:name))
    assert_equal(alphabetical, Book.order("name"))
    assert_equal(alphabetical, Book.order("books.name"))
    assert_equal(alphabetical, Book.order(Book.arel_table["name"]))
    assert_equal(alphabetical, Book.order(books: { name: :asc }))
  end

  def test_order_desc
    z = Book.create!(name: "Zulu", author: authors(:david))
    y = Book.create!(name: "Yankee", author: authors(:mary))
    x = Book.create!(name: "X-Ray", author: authors(:david))

    reverse_alphabetical = [z, y, x]

    assert_equal(reverse_alphabetical, Book.order(name: :desc))
    assert_equal(reverse_alphabetical, Book.order(name: :DESC))
    assert_equal(reverse_alphabetical, Book.order(name: "desc"))
    assert_equal(reverse_alphabetical, Book.order(:name).reverse_order)
    assert_equal(reverse_alphabetical, Book.order("name desc"))
    assert_equal(reverse_alphabetical, Book.order("books.name desc"))
    assert_equal(reverse_alphabetical, Book.order(Book.arel_table["name"].desc))
    assert_equal(reverse_alphabetical, Book.order(books: { name: :desc }))
  end

  def test_order_with_association
    z = Book.create!(name: "Zulu", author: authors(:david))
    y = Book.create!(name: "Yankee", author: authors(:mary))
    x = Book.create!(name: "X-Ray", author: authors(:david))

    author_then_book_name = [x, z, y]

    assert_equal(author_then_book_name, Book.includes(:author).order(authors: { name: :asc }, books: { name: :asc }))
    assert_equal(author_then_book_name, Book.includes(:author).order("authors.name", books: { name: :asc }))
    assert_equal(author_then_book_name, Book.includes(:author).order("authors.name", "books.name"))
    assert_equal(author_then_book_name, Book.includes(:author).order({ authors: { name: :asc } }, Book.arel_table[:name]))
    assert_equal(author_then_book_name, Book.includes(:author).order(Author.arel_table[:name], Book.arel_table[:name]))

    author_desc_then_book_name = [y, x, z]

    assert_equal(author_desc_then_book_name, Book.includes(:author).order(authors: { name: :desc }, books: { name: :asc }))
    assert_equal(author_desc_then_book_name, Book.includes(:author).order("authors.name desc", books: { name: :asc }))
    assert_equal(author_desc_then_book_name, Book.includes(:author).order(Author.arel_table[:name].desc, books: { name: :asc }))
    assert_equal(author_desc_then_book_name, Book.includes(:author).order({ authors: { name: :desc } }, :name))
  end

  def test_order_with_association_alias
    z = Book.create!(name: "Zulu", author: authors(:david))
    y = Book.create!(name: "Yankee", author: authors(:mary))
    x = Book.create!(name: "X-Ray", author: authors(:david))

    author_name = Author.arel_table.alias("author")[:name]

    author_then_book_name = [x, z, y]

    assert_equal(author_then_book_name, Book.includes(:author).order(author: { name: :asc }, books: { name: :asc }))
    assert_equal(author_then_book_name, Book.includes(:author).order("author.name", books: { name: :asc }))
    assert_equal(author_then_book_name, Book.includes(:author).order({ author: { name: :asc } }, :name))
    assert_equal(author_then_book_name, Book.includes(:author).order(author_name, :name))

    author_desc_then_book_name = [y, x, z]

    assert_equal(author_desc_then_book_name, Book.includes(:author).order(author: { name: :desc }, books: { name: :asc }))
    assert_equal(author_desc_then_book_name, Book.includes(:author).order("author.name desc", books: { name: :asc }))
    assert_equal(author_desc_then_book_name, Book.includes(:author).order({ author: { name: :desc } }, :name))
    assert_equal(author_desc_then_book_name, Book.includes(:author).order(author_name.desc, :name))
  end
end
