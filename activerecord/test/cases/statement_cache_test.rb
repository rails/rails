require 'cases/helper'
require 'models/book'
require 'models/liquid'
require 'models/molecule'
require 'models/electron'

module ActiveRecord
  class StatementCacheTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.connection
    end

    def test_statement_cache_with_simple_statement
      cache = ActiveRecord::StatementCache.new do
        Book.where(name: "my book").where("author_id > 3")
      end

      Book.create(name: "my book", author_id: 4)

      books = cache.execute
      assert_equal "my book", books[0].name
    end

    def test_statement_cache_with_nil_statement_raises_error
      assert_raise(ArgumentError) do
        ActiveRecord::StatementCache.new do
          nil
        end
      end
    end

    def test_statement_cache_with_complex_statement
      cache = ActiveRecord::StatementCache.new do
        Liquid.joins(:molecules => :electrons).where('molecules.name' => 'dioxane', 'electrons.name' => 'lepton')
      end

      salty = Liquid.create(name: 'salty')
      molecule = salty.molecules.create(name: 'dioxane')
      molecule.electrons.create(name: 'lepton')

      liquids = cache.execute
      assert_equal "salty", liquids[0].name
    end

    def test_statement_cache_values_differ
      cache = ActiveRecord::StatementCache.new do
        Book.where(name: "my book")
      end

      3.times do
        Book.create(name: "my book")
      end

      first_books = cache.execute

      3.times do
        Book.create(name: "my book")
      end

      additional_books = cache.execute
      assert first_books != additional_books
    end
  end
end
