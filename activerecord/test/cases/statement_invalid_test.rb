# frozen_string_literal: true

require "cases/helper"
require "models/book"

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

    def with_failing_query(connection)
      singleton_class = connection.singleton_class
      singleton_class.define_method(:perform_query) do |_raw_connection, _intent|
        raise MockDatabaseError
      end

      yield
    ensure
      singleton_class.remove_method(:perform_query) if singleton_class&.instance_methods(false)&.include?(:perform_query)
    end

    test "message contains no sql" do
      sql = Book.where(author_id: 96, cover: "hard").to_sql
      connection = Book.lease_connection
      intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(adapter: connection, processed_sql: sql, name: Book.name)
      error = assert_raises(ActiveRecord::StatementInvalid) do
        with_failing_query(connection) do
          intent.execute!
          intent.cast_result
        end
      end
      assert_not error.message.include?("SELECT")
    end

    test "statement and binds are set on select" do
      sql = Book.where(author_id: 96, cover: "hard").to_sql
      binds = [123, 456]
      connection = Book.lease_connection
      intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(adapter: connection, processed_sql: sql, name: Book.name, binds: binds)
      error = assert_raises(ActiveRecord::StatementInvalid) do
        with_failing_query(connection) do
          intent.execute!
          intent.cast_result
        end
      end
      assert_equal error.sql, sql
      assert_equal error.binds, binds
    end
  end
end
