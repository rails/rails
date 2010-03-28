require 'cases/helper'

class PostgresqlActiveSchemaTest < Test::Unit::TestCase
  def setup
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      alias_method :real_execute, :execute
      def execute(sql, name = nil) sql end
    end
  end

  def teardown
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:alias_method, :execute, :real_execute)
  end

  def test_create_database_with_encoding
    assert_equal %(CREATE DATABASE "matt" ENCODING = 'utf8'), create_database(:matt)
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'latin1'), create_database(:aimonetti, :encoding => :latin1)
  end

  def test_create_schema
    assert_equal %(CREATE SCHEMA "rizwan" AUTHORIZATION "postgres"), create_schema(:rizwan, :postgres)
  end

  def test_drop_schema
    assert_equal %(DROP SCHEMA "rizwan"), drop_schema(:rizwan)
  end
  private
    def method_missing(method_symbol, *arguments)
      ActiveRecord::Base.connection.send(method_symbol, *arguments)
    end
end
