# frozen_string_literal: true

require 'cases/helper'
require 'support/connection_helper'
require 'support/schema_dumping_helper'

class PostgresqlBitStringTest < ActiveRecord::PostgreSQLTestCase
  include ConnectionHelper
  include SchemaDumpingHelper

  class PostgresqlBitString < ActiveRecord::Base; end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_bit_strings', force: true) do |t|
      t.bit :a_bit, default: '00000011', limit: 8
      t.bit_varying :a_bit_varying, default: '0011', limit: 4
      t.bit :another_bit
      t.bit_varying :another_bit_varying
    end
  end

  def teardown
    return unless @connection
    @connection.drop_table 'postgresql_bit_strings', if_exists: true
  end

  def test_bit_string_column
    column = PostgresqlBitString.columns_hash['a_bit']
    assert_equal :bit, column.type
    assert_equal 'bit(8)', column.sql_type
    assert_not_predicate column, :array?

    type = PostgresqlBitString.type_for_attribute('a_bit')
    assert_not_predicate type, :binary?
  end

  def test_bit_string_varying_column
    column = PostgresqlBitString.columns_hash['a_bit_varying']
    assert_equal :bit_varying, column.type
    assert_equal 'bit varying(4)', column.sql_type
    assert_not_predicate column, :array?

    type = PostgresqlBitString.type_for_attribute('a_bit_varying')
    assert_not_predicate type, :binary?
  end

  def test_default
    assert_equal '00000011', PostgresqlBitString.column_defaults['a_bit']
    assert_equal '00000011', PostgresqlBitString.new.a_bit

    assert_equal '0011', PostgresqlBitString.column_defaults['a_bit_varying']
    assert_equal '0011', PostgresqlBitString.new.a_bit_varying
  end

  def test_schema_dumping
    output = dump_table_schema('postgresql_bit_strings')
    assert_match %r{t\.bit\s+"a_bit",\s+limit: 8,\s+default: "00000011"$}, output
    assert_match %r{t\.bit_varying\s+"a_bit_varying",\s+limit: 4,\s+default: "0011"$}, output
  end

  if ActiveRecord::Base.connection.prepared_statements
    def test_assigning_invalid_hex_string_raises_exception
      assert_raises(ActiveRecord::StatementInvalid) { PostgresqlBitString.create! a_bit: 'FF' }
      assert_raises(ActiveRecord::StatementInvalid) { PostgresqlBitString.create! a_bit_varying: 'F' }
    end
  end

  def test_roundtrip
    record = PostgresqlBitString.create!(a_bit: '00001010', a_bit_varying: '0101')
    assert_equal '00001010', record.a_bit
    assert_equal '0101', record.a_bit_varying
    assert_nil record.another_bit
    assert_nil record.another_bit_varying

    record.a_bit = '11111111'
    record.a_bit_varying = '0xF'
    record.save!

    assert record.reload
    assert_equal '11111111', record.a_bit
    assert_equal '1111', record.a_bit_varying
  end
end
