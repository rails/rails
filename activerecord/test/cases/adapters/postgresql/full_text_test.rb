require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlFullTextTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper
  class Tsvector < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table("tsvectors") do |t|
      t.tsvector "text_vector"
    end
  end

  teardown do
    @connection.drop_table "tsvectors", if_exists: true
  end

  def test_tsvector_column
    column = Tsvector.columns_hash["text_vector"]
    assert_equal :tsvector, column.type
    assert_equal "tsvector", column.sql_type
    assert_not column.array?

    type = Tsvector.type_for_attribute("text_vector")
    assert_not type.binary?
  end

  def test_update_tsvector
    Tsvector.create text_vector: "'text' 'vector'"
    tsvector = Tsvector.first
    assert_equal "'text' 'vector'", tsvector.text_vector

    tsvector.text_vector = "'new' 'text' 'vector'"
    tsvector.save!
    assert tsvector.reload
    assert_equal "'new' 'text' 'vector'", tsvector.text_vector
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema("tsvectors")
    assert_match %r{t\.tsvector "text_vector"}, output
  end
end
