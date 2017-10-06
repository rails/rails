# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class Mysql2UnsignedTypeTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  class UnsignedType < ActiveRecord::Base
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table("unsigned_types", force: true) do |t|
      t.integer :unsigned_integer, unsigned: true
      t.bigint  :unsigned_bigint,  unsigned: true
      t.float   :unsigned_float,   unsigned: true
      t.decimal :unsigned_decimal, unsigned: true, precision: 10, scale: 2
      t.column  :unsigned_zerofill, "int unsigned zerofill"
    end
  end

  teardown do
    @connection.drop_table "unsigned_types", if_exists: true
  end

  test "unsigned int max value is in range" do
    assert expected = UnsignedType.create(unsigned_integer: 4294967295)
    assert_equal expected, UnsignedType.find_by(unsigned_integer: 4294967295)
  end

  test "minus value is out of range" do
    assert_raise(ActiveModel::RangeError) do
      UnsignedType.create(unsigned_integer: -10)
    end
    assert_raise(ActiveModel::RangeError) do
      UnsignedType.create(unsigned_bigint: -10)
    end
    assert_raise(ActiveRecord::RangeError) do
      UnsignedType.create(unsigned_float: -10.0)
    end
    assert_raise(ActiveRecord::RangeError) do
      UnsignedType.create(unsigned_decimal: -10.0)
    end
  end

  test "schema definition can use unsigned as the type" do
    @connection.change_table("unsigned_types") do |t|
      t.unsigned_integer :unsigned_integer_t
      t.unsigned_bigint  :unsigned_bigint_t
      t.unsigned_float   :unsigned_float_t
      t.unsigned_decimal :unsigned_decimal_t, precision: 10, scale: 2
    end

    @connection.columns("unsigned_types").select { |c| /^unsigned_/.match?(c.name) }.each do |column|
      assert column.unsigned?
    end
  end

  test "schema dump includes unsigned option" do
    schema = dump_table_schema "unsigned_types"
    assert_match %r{t\.integer\s+"unsigned_integer",\s+unsigned: true$}, schema
    assert_match %r{t\.bigint\s+"unsigned_bigint",\s+unsigned: true$}, schema
    assert_match %r{t\.float\s+"unsigned_float",\s+unsigned: true$}, schema
    assert_match %r{t\.decimal\s+"unsigned_decimal",\s+precision: 10,\s+scale: 2,\s+unsigned: true$}, schema
  end
end
