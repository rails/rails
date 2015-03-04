require "cases/helper"
require 'support/schema_dumping_helper'

class PostgresqlSerialTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  class PostgresqlSerial < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table "postgresql_serials", force: true do |t|
      t.serial :seq
    end
  end

  teardown do
    @connection.drop_table "postgresql_serials", if_exists: true
  end

  def test_serial_column
    column = PostgresqlSerial.columns_hash["seq"]
    assert_equal :integer, column.type
    assert_equal "integer", column.sql_type
    assert column.serial?
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema "postgresql_serials"
    assert_match %r{t\.serial\s+"seq"}, output
  end
end

class PostgresqlBigSerialTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  class PostgresqlBigSerial < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table "postgresql_big_serials", force: true do |t|
      t.bigserial :seq
    end
  end

  teardown do
    @connection.drop_table "postgresql_big_serials", if_exists: true
  end

  def test_bigserial_column
    column = PostgresqlBigSerial.columns_hash["seq"]
    assert_equal :integer, column.type
    assert_equal "bigint", column.sql_type
    assert column.serial?
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema "postgresql_big_serials"
    assert_match %r{t\.bigserial\s+"seq"}, output
  end
end
