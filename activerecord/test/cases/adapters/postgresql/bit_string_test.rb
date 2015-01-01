# -*- coding: utf-8 -*-
require "cases/helper"
require 'support/connection_helper'
require 'support/schema_dumping_helper'

class PostgresqlBitStringTest < ActiveRecord::TestCase
  include ConnectionHelper
  include SchemaDumpingHelper

  class PostgresqlBitString < ActiveRecord::Base; end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_bit_strings', :force => true) do |t|
      t.bit :a_bit, default: "00000011", limit: 8
      t.bit_varying :a_bit_varying, default: "0011", limit: 4
    end
  end

  def teardown
    return unless @connection
    @connection.execute 'DROP TABLE IF EXISTS postgresql_bit_strings'
  end

  def test_bit_string_column
    column = PostgresqlBitString.columns_hash["a_bit"]
    assert_equal :bit, column.type
    assert_equal "bit(8)", column.sql_type
    assert_not column.number?
    assert_not column.binary?
    assert_not column.array?
  end

  def test_bit_string_varying_column
    column = PostgresqlBitString.columns_hash["a_bit_varying"]
    assert_equal :bit_varying, column.type
    assert_equal "bit varying(4)", column.sql_type
    assert_not column.number?
    assert_not column.binary?
    assert_not column.array?
  end

  def test_default
    assert_equal "00000011", PostgresqlBitString.column_defaults['a_bit']
    assert_equal "00000011", PostgresqlBitString.new.a_bit

    assert_equal "0011", PostgresqlBitString.column_defaults['a_bit_varying']
    assert_equal "0011", PostgresqlBitString.new.a_bit_varying
  end

  def test_schema_dumping
    output = dump_table_schema("postgresql_bit_strings")
    assert_match %r{t\.bit\s+"a_bit",\s+limit: 8,\s+default: "00000011"$}, output
    assert_match %r{t\.bit_varying\s+"a_bit_varying",\s+limit: 4,\s+default: "0011"$}, output
  end

  def test_assigning_invalid_hex_string_raises_exception
    assert_raises(ActiveRecord::StatementInvalid) { PostgresqlBitString.create! a_bit: "FF" }
    assert_raises(ActiveRecord::StatementInvalid) { PostgresqlBitString.create! a_bit_varying: "FF" }
  end

  def test_roundtrip
    PostgresqlBitString.create! a_bit: "00001010", a_bit_varying: "0101"
    record = PostgresqlBitString.first
    assert_equal "00001010", record.a_bit
    assert_equal "0101", record.a_bit_varying

    record.a_bit = "11111111"
    record.a_bit_varying = "0xF"
    record.save!

    assert record.reload
    assert_equal "11111111", record.a_bit
    assert_equal "1111", record.a_bit_varying
  end
end
