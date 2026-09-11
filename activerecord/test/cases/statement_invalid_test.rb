# frozen_string_literal: true

require "cases/helper"
require "models/book"

module ActiveRecord
  class StatementInvalidTest < ActiveRecord::TestCase
    fixtures :books

    def setup
      super
      @connection = ActiveRecord::Base.connection_pool.send(:new_connection)
      @connection.connect!
    end

    def teardown
      @connection.disconnect!
      super
    end

    class MockDatabaseError < StandardError
      def result
        0
      end

      def error_number
        0
      end
    end

    test "message contains no sql" do
      sql = Book.where(author_id: 96, cover: "hard").to_sql
      connection = @connection
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
      connection = @connection
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

    private
      def with_failing_query(connection, &block)
        connection.stub(:perform_query, ->(*) { raise MockDatabaseError }, &block)
      end
  end
end
