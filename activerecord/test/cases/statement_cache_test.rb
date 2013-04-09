require "cases/helper"
require "models/book"

module ActiveRecord
  class StatementCacheTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.connection
    end

    def test_statement_cache_with_simple_statement
      cache = ActiveRecord::StatementCache.new do
        Book.where(:name => "my book").limit(100)
      end

      Book.create(name: "my book")

      book = cache.execute
      assert_equal "my book", book[0].name     
    end

    def test_statement_cache_with_longer_statement
      cache = ActiveRecord::StatementCache.new do
        Book.where(:name => "my book").where("author_id > 3")
      end

      Book.create(name: "my book", author_id: 4)

      book = cache.execute
      assert_equal "my book", book[0].name     
    end

    def test_statement_cache_values_differ
      cache = ActiveRecord::StatementCache.new do
        Book.where(:name => "my book")
      end
      for i in 0..2 do
        Book.create(name: "my book")
      end

      first_books = cache.execute
      
      for i in 0..2 do
        Book.create(name: "my book")
      end

      additional_books = cache.execute

      assert first_books != additional_books 
    end
  end
end
