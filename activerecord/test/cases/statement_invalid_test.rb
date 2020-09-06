# frozen_string_literal: true

require 'cases/helper'
require 'models/book'

module ActiveRecord
  class StatementInvalidTest < ActiveRecord::TestCase
    fixtures :books

    class MockDatabaseError < StandardError
      def result
        0
      end

      def error_number
        0
      end
    end

    test 'message contains no sql' do
      sql = Book.where(author_id: 96, cover: 'hard').to_sql
      error = assert_raises(ActiveRecord::StatementInvalid) do
        Book.connection.send(:log, sql, Book.name) do
          raise MockDatabaseError
        end
      end
      assert_not error.message.include?('SELECT')
    end

    test 'statement and binds are set on select' do
      sql = Book.where(author_id: 96, cover: 'hard').to_sql
      binds = [Minitest::Mock.new, Minitest::Mock.new]
      error = assert_raises(ActiveRecord::StatementInvalid) do
        Book.connection.send(:log, sql, Book.name, binds) do
          raise MockDatabaseError
        end
      end
      assert_equal error.sql, sql
      assert_equal error.binds, binds
    end
  end
end
