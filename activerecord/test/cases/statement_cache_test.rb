# frozen_string_literal: true

require "cases/helper"
require "models/book"
require "models/liquid"
require "models/molecule"
require "models/numeric_data"
require "models/electron"
require "models/clothing_item"

module ActiveRecord
  class StatementCacheTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.lease_connection
    end

    def test_statement_cache
      Book.create(name: "my book")
      Book.create(name: "my other book")

      cache = StatementCache.create(ClothingItem.lease_connection) do |params|
        Book.where(name: params.bind)
      end

      b = cache.execute([ "my book" ], ClothingItem.lease_connection)
      assert_equal "my book", b[0].name
      b = cache.execute([ "my other book" ], ClothingItem.lease_connection)
      assert_equal "my other book", b[0].name
    end

    def test_statement_cache_id
      b1 = Book.create(name: "my book")
      b2 = Book.create(name: "my other book")

      cache = StatementCache.create(ClothingItem.lease_connection) do |params|
        Book.where(id: params.bind)
      end

      b = cache.execute([ b1.id ], ClothingItem.lease_connection)
      assert_equal b1.name, b[0].name
      b = cache.execute([ b2.id ], ClothingItem.lease_connection)
      assert_equal b2.name, b[0].name
    end

    def test_positional_parameters_follow_declaration_order
      first = Book.create!(name: "First", author_id: 1)
      second = Book.create!(name: "Second", author_id: 2)

      each_statement_mode do
        cache = StatementCache.create(@connection) do |params|
          name = params.bind
          author_id = params.bind
          Book.where(author_id: author_id, name: name).where.not(id: -1)
        end

        assert_equal [first], cache.execute([first.name, first.author_id], @connection)
        assert_equal [second], cache.execute([second.name, second.author_id], @connection)
      end
    end

    def test_repeated_parameters_share_one_input
      first = Book.create!(name: "Matched", isbn: "Other")
      second = Book.create!(name: "Other", isbn: "Matched")

      each_statement_mode do
        cache = StatementCache.create(@connection) do |params|
          value = params.bind
          Book.where(name: value).or(Book.where(isbn: value)).order(:id)
        end

        assert_equal [first, second].sort_by(&:id), cache.execute(["Matched"], @connection)
        assert_empty cache.execute(["Absent"], @connection)
      end
    end

    def test_removed_parameters_do_not_shift_later_inputs
      book = Book.create!(name: nil, author_id: 3)

      each_statement_mode do
        cache = StatementCache.create(@connection) do |params|
          Book.where(name: params.bind, author_id: params.bind).rewhere(name: nil)
        end

        assert_equal [book], cache.execute(["Unused", book.author_id], @connection)
      end
    end

    def test_named_parameters_can_be_supplied_by_a_hash
      enabled = Book.create!(name: "Enabled", author_id: 4, boolean_status: true)
      disabled = Book.create!(name: "Disabled", author_id: 4, boolean_status: false)

      each_statement_mode do
        cache = StatementCache.create(@connection) do |params|
          Book.where(author_id: params.bind(:owner_id), boolean_status: params.bind(:enabled))
        end

        assert_equal [enabled], cache.execute({ enabled: true, owner_id: 4 }, @connection)
        assert_equal [disabled], cache.execute({ enabled: false, owner_id: 4 }, @connection)
      end
    end

    def test_nil_and_false_parameter_keys_with_fixed_binds
      book = Book.create!(name: "Named keys", isbn: "fixed-bind-isbn", author_id: 4, boolean_status: true)

      each_statement_mode do
        cache = StatementCache.create(@connection) do |params|
          Book.where(isbn: book.isbn, name: params.bind(nil), boolean_status: true, author_id: params.bind(false))
        end

        assert_equal [book], cache.execute({ nil => book.name, false => book.author_id }, @connection)
        assert_empty cache.execute({ nil => "Other name", false => book.author_id }, @connection)
      end
    end

    def test_named_parameters_can_be_supplied_by_a_reader
      first = Book.create!(name: "First", author_id: 5)
      second = Book.create!(name: "Second", author_id: 6)

      each_statement_mode do
        cache = StatementCache.create(@connection) do |params|
          Book.where(author_id: params.bind("id"), name: params.bind("title"))
        end

        first_owner = Book.new(id: first.author_id, title: first.name)
        second_owner = Book.new(id: second.author_id, title: second.name)
        assert_equal [first], cache.execute(first_owner.method(:read_attribute), @connection)
        assert_equal [second], cache.execute(second_owner.method(:read_attribute), @connection)
      end
    end

    def test_find_or_create_by
      Book.create(name: "my book")

      a = Book.find_or_create_by(name: "my book")
      b = Book.find_or_create_by(name: "my other book")

      assert_equal("my book", a.name)
      assert_equal("my other book", b.name)
    end

    def test_statement_cache_with_simple_statement
      cache = ActiveRecord::StatementCache.create(ClothingItem.lease_connection) do |params|
        Book.where(name: "my book").where("author_id > 3")
      end

      Book.create(name: "my book", author_id: 4)

      books = cache.execute([], ClothingItem.lease_connection)
      assert_equal "my book", books[0].name
    end

    def test_statement_cache_with_complex_statement
      cache = ActiveRecord::StatementCache.create(ClothingItem.lease_connection) do |params|
        Liquid.joins(molecules: :electrons).where("molecules.name" => "dioxane", "electrons.name" => "lepton")
      end

      salty = Liquid.create(name: "salty")
      molecule = salty.molecules.create(name: "dioxane")
      molecule.electrons.create(name: "lepton")

      liquids = cache.execute([], ClothingItem.lease_connection)
      assert_equal "salty", liquids[0].name
    end

    def test_statement_cache_with_strictly_cast_attribute
      row = NumericData.create(temperature: 1.5)
      assert_equal row, NumericData.find_by(temperature: 1.5)
    end

    def test_statement_cache_values_differ
      cache = ActiveRecord::StatementCache.create(ClothingItem.lease_connection) do |params|
        Book.where(name: "my book")
      end

      3.times do
        Book.create(name: "my book")
      end

      first_books = cache.execute([], ClothingItem.lease_connection)

      3.times do
        Book.create(name: "my book")
      end

      additional_books = cache.execute([], ClothingItem.lease_connection)
      assert_not_equal first_books, additional_books
    end

    def test_unprepared_statements_dont_share_a_cache_with_prepared_statements
      Book.create(name: "my book")
      Book.create(name: "my other book")

      book = Book.find_by(name: "my book")
      other_book = Book.lease_connection.unprepared_statement do
        Book.find_by(name: "my other book")
      end

      assert_not_equal book, other_book
    end

    def test_out_of_range_bind_value_returns_an_empty_result
      cache = Book.lease_connection.unprepared_statement do
        StatementCache.create(Book.lease_connection) do |params|
          Book.where(id: params.bind)
        end
      end

      assert_equal [], cache.execute([2 << 63], Book.lease_connection)
    end

    def test_out_of_range_bind_value_returns_an_empty_result_when_async
      cache = Book.lease_connection.unprepared_statement do
        StatementCache.create(Book.lease_connection) do |params|
          Book.where(id: params.bind)
        end
      end

      promise = cache.execute([2 << 63], Book.lease_connection, async: true)

      assert promise.is_a?(ActiveRecord::Promise)
      assert_equal [], promise.value
    end

    def test_find_by_does_not_use_statement_cache_if_table_name_is_changed
      liquid = Liquid.create(name: "salty")

      Liquid.find_by(name: liquid.name) # warming the statement cache.

      # changing the table name should change the query that is not cached.
      Liquid.table_name = :birds
      assert_nil Liquid.find_by(name: liquid.name)
    ensure
      Liquid.table_name = :liquid
    end

    def test_find_does_not_use_statement_cache_if_table_name_is_changed
      liquid = Liquid.create(name: "salty")

      Liquid.find(liquid.id) # warming the statement cache.

      # changing the table name should change the query that is not cached.
      Liquid.table_name = :birds
      assert_raise ActiveRecord::RecordNotFound do
        Liquid.find(liquid.id)
      end
    ensure
      Liquid.table_name = :liquid
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

    private
      def each_statement_mode(&)
        yield
        @connection.unprepared_statement(&)
      end
  end
end
