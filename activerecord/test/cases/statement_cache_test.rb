# frozen_string_literal: true

require "cases/helper"
require "models/book"
require "models/liquid"
require "models/molecule"
require "models/numeric_data"
require "models/electron"

module ActiveRecord
  class StatementCacheTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.connection
    end

    def test_statement_cache
      Book.create(name: "my book")
      Book.create(name: "my other book")

      cache = StatementCache.create(Book.connection) do |params|
        Book.where(name: params.bind)
      end

      b = cache.execute([ "my book" ], Book.connection)
      assert_equal "my book", b[0].name
      b = cache.execute([ "my other book" ], Book.connection)
      assert_equal "my other book", b[0].name
    end

    def test_statement_cache_id
      b1 = Book.create(name: "my book")
      b2 = Book.create(name: "my other book")

      cache = StatementCache.create(Book.connection) do |params|
        Book.where(id: params.bind)
      end

      b = cache.execute([ b1.id ], Book.connection)
      assert_equal b1.name, b[0].name
      b = cache.execute([ b2.id ], Book.connection)
      assert_equal b2.name, b[0].name
    end

    def test_find_or_create_by
      Book.create(name: "my book")

      a = Book.find_or_create_by(name: "my book")
      b = Book.find_or_create_by(name: "my other book")

      assert_equal("my book", a.name)
      assert_equal("my other book", b.name)
    end

    def test_statement_cache_with_simple_statement
      cache = ActiveRecord::StatementCache.create(Book.connection) do |params|
        Book.where(name: "my book").where("author_id > 3")
      end

      Book.create(name: "my book", author_id: 4)

      books = cache.execute([], Book.connection)
      assert_equal "my book", books[0].name
    end

    def test_statement_cache_with_complex_statement
      cache = ActiveRecord::StatementCache.create(Book.connection) do |params|
        Liquid.joins(molecules: :electrons).where("molecules.name" => "dioxane", "electrons.name" => "lepton")
      end

      salty = Liquid.create(name: "salty")
      molecule = salty.molecules.create(name: "dioxane")
      molecule.electrons.create(name: "lepton")

      liquids = cache.execute([], Book.connection)
      assert_equal "salty", liquids[0].name
    end

    def test_statement_cache_with_strictly_cast_attribute
      row = NumericData.create(temperature: 1.5)
      assert_equal row, NumericData.find_by(temperature: 1.5)
    end

    def test_statement_cache_values_differ
      cache = ActiveRecord::StatementCache.create(Book.connection) do |params|
        Book.where(name: "my book")
      end

      3.times do
        Book.create(name: "my book")
      end

      first_books = cache.execute([], Book.connection)

      3.times do
        Book.create(name: "my book")
      end

      additional_books = cache.execute([], Book.connection)
      assert first_books != additional_books
    end

    def test_unprepared_statements_dont_share_a_cache_with_prepared_statements
      Book.create(name: "my book")
      Book.create(name: "my other book")

      book = Book.find_by(name: "my book")
      other_book = Book.connection.unprepared_statement do
        Book.find_by(name: "my other book")
      end

      assert_not_equal book, other_book
    end

    def test_find_by_does_not_use_statement_cache_if_table_name_is_changed
      book = Book.create(name: "my book")

      Book.find_by(name: book.name) # warming the statement cache.

      # changing the table name should change the query that is not cached.
      Book.table_name = :birds
      assert_nil Book.find_by(name: book.name)
    ensure
      Book.table_name = :books
    end

    def test_find_does_not_use_statement_cache_if_table_name_is_changed
      book = Book.create(name: "my book")

      Book.find(book.id) # warming the statement cache.

      # changing the table name should change the query that is not cached.
      Book.table_name = :birds
      assert_raise ActiveRecord::RecordNotFound do
        Book.find(book.id)
      end
    ensure
      Book.table_name = :books
    end

    def test_find_association_does_not_use_statement_cache_if_table_name_is_changed
      salty = Liquid.create(name: "salty")
      molecule = salty.molecules.create(name: "dioxane")

      assert_equal salty, molecule.liquid

      Liquid.table_name = :birds

      assert_nil molecule.reload_liquid
    ensure
      Liquid.table_name = :liquid
    end
  end
end
