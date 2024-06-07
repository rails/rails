# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlSerialTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class PostgresqlSerial < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table "postgresql_serials", force: true do |t|
      t.serial :seq
      t.integer :serials_id, default: -> { "nextval('postgresql_serials_id_seq')" }
    end
  end

  teardown do
    @connection.drop_table "postgresql_serials", if_exists: true
  end

  def test_serial_column
    column = PostgresqlSerial.columns_hash["seq"]
    assert_equal :integer, column.type
    assert_equal "integer", column.sql_type
    assert_predicate column, :serial?
  end

  def test_not_serial_column
    column = PostgresqlSerial.columns_hash["serials_id"]
    assert_equal :integer, column.type
    assert_equal "integer", column.sql_type
    assert_not_predicate column, :serial?
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema "postgresql_serials"
    assert_match %r{t\.serial\s+"seq",\s+null: false$}, output
  end

  def test_schema_dump_with_not_serial
    output = dump_table_schema "postgresql_serials"
    assert_match %r{t\.integer\s+"serials_id",\s+default: -> \{ "nextval\('postgresql_serials_id_seq'::regclass\)" \}$}, output
  end
end

class PostgresqlBigSerialTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class PostgresqlBigSerial < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table "postgresql_big_serials", force: true do |t|
      t.bigserial :seq
      t.bigint :serials_id, default: -> { "nextval('postgresql_big_serials_id_seq')" }
    end
  end

  teardown do
    @connection.drop_table "postgresql_big_serials", if_exists: true
  end

  def test_bigserial_column
    column = PostgresqlBigSerial.columns_hash["seq"]
    assert_equal :integer, column.type
    assert_equal "bigint", column.sql_type
    assert_predicate column, :serial?
  end

  def test_not_bigserial_column
    column = PostgresqlBigSerial.columns_hash["serials_id"]
    assert_equal :integer, column.type
    assert_equal "bigint", column.sql_type
    assert_not_predicate column, :serial?
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema "postgresql_big_serials"
    assert_match %r{t\.bigserial\s+"seq",\s+null: false$}, output
  end

  def test_schema_dump_with_not_bigserial
    output = dump_table_schema "postgresql_big_serials"
    assert_match %r{t\.bigint\s+"serials_id",\s+default: -> \{ "nextval\('postgresql_big_serials_id_seq'::regclass\)" \}$}, output
  end
end

module SequenceNameDetectionTestCases
  class CollidedSequenceNameTest < ActiveRecord::PostgreSQLTestCase
    include SchemaDumpingHelper

    def setup
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table :foo_bar, force: true do |t|
        t.serial :baz_id
      end
      @connection.create_table :foo, force: true do |t|
        t.serial :bar_id
        t.bigserial :bar_baz_id
      end
    end

    def teardown
      @connection.drop_table :foo_bar, if_exists: true
      @connection.drop_table :foo, if_exists: true
    end

    def test_serial_columns
      columns = @connection.columns(:foo)
      columns.each do |column|
        assert_equal :integer, column.type
        assert_predicate column, :serial?
      end
    end

    def test_schema_dump_with_collided_sequence_name
      output = dump_table_schema "foo"
      assert_match %r{t\.serial\s+"bar_id",\s+null: false$}, output
      assert_match %r{t\.bigserial\s+"bar_baz_id",\s+null: false$}, output
    end
  end

  class LongerSequenceNameDetectionTest < ActiveRecord::PostgreSQLTestCase
    include SchemaDumpingHelper

    def setup
      @table_name = "long_table_name_to_test_sequence_name_detection_for_serial_cols"
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table @table_name, force: true, _uses_legacy_table_name: true do |t|
        t.serial :seq
        t.bigserial :bigseq
      end
    end

    def teardown
      @connection.drop_table @table_name, if_exists: true
    end

    def test_serial_columns
      columns = @connection.columns(@table_name)
      columns.each do |column|
        assert_equal :integer, column.type
        assert_predicate column, :serial?
      end
    end

    def test_schema_dump_with_long_table_name
      output = dump_table_schema @table_name
      assert_match %r{create_table "#{@table_name}", force: :cascade}, output
      assert_match %r{t\.serial\s+"seq",\s+null: false$}, output
      assert_match %r{t\.bigserial\s+"bigseq",\s+null: false$}, output
    end
  end
end
