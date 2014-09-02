# encoding: utf-8
require "cases/helper"

class PostgresqlFullTextTest < ActiveRecord::TestCase
  class PostgresqlTsvector < ActiveRecord::Base; end

  def test_tsvector_column
    column = PostgresqlTsvector.columns_hash["text_vector"]
    assert_equal :tsvector, column.type
    assert_equal "tsvector", column.sql_type
    assert_not column.number?
    assert_not column.binary?
    assert_not column.array
  end

  def test_update_tsvector
    PostgresqlTsvector.create text_vector: "'text' 'vector'"
    tsvector = PostgresqlTsvector.first
    assert_equal "'text' 'vector'", tsvector.text_vector

    tsvector.text_vector = "'new' 'text' 'vector'"
    tsvector.save!
    assert tsvector.reload
    assert_equal "'new' 'text' 'vector'", tsvector.text_vector
  end
end
