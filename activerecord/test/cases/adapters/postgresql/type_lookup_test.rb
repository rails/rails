# frozen_string_literal: true

require "cases/helper"

class PostgresqlTypeLookupTest < ActiveRecord::PostgreSQLTestCase
  setup do
    @connection = ActiveRecord::Base.lease_connection
  end

  test "array delimiters are looked up correctly" do
    box_array = @connection.send(:type_map).lookup(1020)
    int_array = @connection.send(:type_map).lookup(1007)

    assert_equal ";", box_array.delimiter
    assert_equal ",", int_array.delimiter
  end

  test "array types correctly respect registration of subtypes" do
    int_array = @connection.send(:type_map).lookup(1007, -1, "integer[]")
    bigint_array = @connection.send(:type_map).lookup(1016, -1, "bigint[]")
    big_array = [123456789123456789]

    assert_raises(ActiveModel::RangeError) { int_array.serialize(big_array) }
    assert_equal "{123456789123456789}", @connection.type_cast(bigint_array.serialize(big_array))
  end

  test "range types correctly respect registration of subtypes" do
    int_range = @connection.send(:type_map).lookup(3904, -1, "int4range")
    bigint_range = @connection.send(:type_map).lookup(3926, -1, "int8range")
    big_range = 0..123456789123456789

    assert_raises(ActiveModel::RangeError) { int_range.serialize(big_range) }
    assert_equal "[0,123456789123456789]", @connection.type_cast(bigint_range.serialize(big_range))
  end
end
